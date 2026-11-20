import Foundation

class LrclibLyricsRepository: LyricsRepository {
    private let endpointLock = NSLock()
    private var endpoint: String
    var apiUrl: String {
        get { endpointLock.lock(); defer { endpointLock.unlock() }; return endpoint }
        set { endpointLock.lock(); endpoint = newValue; endpointLock.unlock() }
    }
    private let session: URLSession

    private init(apiUrl: String) {
        self.endpoint = apiUrl

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = [
            "User-Agent": "EeveeSpotify v\(EeveeSpotify.version) https://github.com/zbzxbg/EeveeSpotifyEvolved"
        ]
        // LRCLIB 偶尔很慢：给 10s（原来用系统默认值，直连与回退两次尝试都会卡在同一拍上）。
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.waitsForConnectivity = false

        // Let URLSession resolve DNS, select IPv4/IPv6 and validate the actual
        // request hostname. No synchronous resolver or pinned initial hostname.
        session = URLSession(configuration: configuration)
    }

    static let originalApiUrl = "https://lrclib.net/api"

    static let shared = LrclibLyricsRepository(
        apiUrl: UserDefaults.lyricsOptions.lrclibUrl
    )

    private func perform(
        _ path: String,
        query: [String:Any] = [:]
    ) throws -> Data {
        var stringUrl = "\(apiUrl)\(path)"

        if !query.isEmpty {
            let queryString = query.queryString
            stringUrl += "?\(queryString)"
        }

        guard let url = URL(string: stringUrl) else {
            writeDebugLog("[LRCLIB] Bad URL: \(stringUrl)")
            throw LyricsError.decodingError
        }

        var request = URLRequest(url: url)

        let semaphore = DispatchSemaphore(value: 0)
        var data: Data?
        var error: Error?

        let task = session.dataTask(with: request) { responseData, _, err in
            error = err
            data = responseData
            semaphore.signal()
        }

        task.resume()
        guard LyricsRequestBudget.wait(semaphore, task: task) else { throw URLError(.timedOut) }


        if let error = error {
            writeDebugLog("[LRCLIB] Request error for \(stringUrl): \(error)")
            throw error
        }

        guard let data else {
            writeDebugLog("[LRCLIB] No data returned for \(stringUrl)")
            throw LyricsError.decodingError
        }

        writeDebugLog("[LRCLIB] \(stringUrl) -> \(data.count) bytes")
        return data
    }

    private func getSong(trackName: String, artistName: String) throws -> LrclibSong {
        let data: Data = try perform("/get", query: [
            "track_name": trackName,
            "artist_name": artistName
        ])
        do {
            return try JSONDecoder().decode(LrclibSong.self, from: data)
        } catch {
            // 只报 decodingError 看不出是"没这首歌"还是"回了个 HTML/错误页" ⇒ 带上响应体。
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            writeDebugLog("[LRCLIB] Decode error for \(trackName)/\(artistName): \(error). Body: \(body.prefix(300))")
            throw error
        }
    }

    private func mapSyncedLyricsLines(_ lines: [String]) -> [LyricsLineDto] {
        return lines.compactMap { line in
            guard let match = line.firstMatch(
                "\\[(?<minute>\\d*):(?<seconds>\\d+\\.\\d+|\\d+)\\] ?(?<content>.*)"
            ) else {
                return nil
            }

            var captures: [String: String] = [:]

            for name in ["minute", "seconds", "content"] {
                let matchRange = match.range(withName: name)

                if let substringRange = Range(matchRange, in: line) {
                    captures[name] = String(line[substringRange])
                }
            }

            let minute = Int(captures["minute"]!)!
            let seconds = Float(captures["seconds"]!)!
            let content = captures["content"]!

            return LyricsLineDto(
                content: content.lyricsNoteIfEmpty,
                offsetMs: Int(minute * 60 * 1000 + Int(seconds * 1000))
            )
        }
    }

    /// Every name the same recording is likely filed under.
    ///
    /// Spotify titles carry suffixes (`Song (feat. X)`, `Song - Remastered
    /// 2011`) that LRCLIB's `/get` endpoint does not accept, so one exact-match
    /// request reports "no lyrics" for songs LRCLIB actually has. Candidates
    /// are deduplicated case-insensitively and tried in order.
    private func titleCandidates(for title: String) -> [String] {
        var names: [String] = []
        for candidate in [
            title,
            title.strippedTrackTitle,
            LyricsMatch.baseTitle(title),
            LyricsMatch.baseTitle(title).strippedTrackTitle,
        ] {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !names.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
            else { continue }
            names.append(trimmed)
        }
        return names
    }

    /// One search hit from `/search`. Field names are the response's own keys.
    private struct SearchHit: Decodable {
        var trackName: String
        var artistName: String
        var duration: Double?
        var instrumental: Bool?
        var plainLyrics: String?
        var syncedLyrics: String?
    }

    /// Resolve the track: exact matches first, then a scored search.
    private func lookup(_ query: LyricsSearchQuery) throws -> LrclibSong {
        var lastError: Error?
        for title in titleCandidates(for: query.title) {
            do {
                return try getSong(trackName: title, artistName: query.primaryArtist)
            } catch let error {
                lastError = error
                writeDebugLog("[LRCLIB] no exact match for \"\(title)\": \(error)")
            }
        }
        if let hit = try? search(query) {
            writeDebugLog("[LRCLIB] search matched \"\(hit.name)\"")
            return hit
        }
        throw lastError ?? LyricsError.noSuchSong
    }

    /// `/search` plus scoring. Title and duration are the hard gates (a
    /// different recording would put someone else's words on this track); a
    /// matching artist only breaks ties.
    private func search(_ query: LyricsSearchQuery) throws -> LrclibSong? {
        let data = try perform("/search", query: [
            "track_name": LyricsMatch.baseTitle(query.title),
            "artist_name": query.primaryArtist,
        ])
        guard let hits = try? JSONDecoder().decode([SearchHit].self, from: data),
              !hits.isEmpty else {
            writeDebugLog("[LRCLIB] search returned no usable hits")
            return nil
        }

        let wantedNames = ([query.title, query.title.strippedTrackTitle] + query.titleVariants)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let trackMs = query.durationMs

        var best: (hit: SearchHit, score: Int)?
        for hit in hits {
            let candidateNames = [hit.trackName, hit.trackName.strippedTrackTitle]
            guard candidateNames.contains(where: { candidate in
                wantedNames.contains { LyricsMatch.titlesMatch(candidate, $0) }
            }) else { continue }
            guard let duration = hit.duration, duration > 0 else { continue }
            let gap = LyricsMatch.lengthGap(Int(duration * 1000), trackMs) ?? 0
            guard gap <= 10_000 else { continue }
            let artistMatches = query.allArtistNames.contains {
                LyricsMatch.sameArtist(hit.artistName, $0)
            }
            let score = (artistMatches ? 0 : 1_000) + gap
            if let best, best.score <= score { continue }
            best = (hit, score)
        }

        guard let best else {
            writeDebugLog(
                "[LRCLIB] search had \(hits.count) hit(s), none matched title/artist/duration"
            )
            return nil
        }
        return LrclibSong(
            name: best.hit.trackName,
            plainLyrics: best.hit.plainLyrics,
            syncedLyrics: best.hit.syncedLyrics,
            instrumental: best.hit.instrumental ?? false
        )
    }

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        writeDebugLog("[LRCLIB] Fetching lyrics for \"\(query.title)\" - \(query.primaryArtist)")
        let song = try lookup(query)

        if song.instrumental {
            writeDebugLog("[LRCLIB] Instrumental — returning empty lyrics")
            return LyricsDto(
                lines: [],
                timeSynced: false,
                romanization: .original,
                // 同上 —— 源明确判定过，听歌页据此写「此歌曲为纯音乐。」。
                isInstrumental: true
            )
        }

        // `!syncedLyrics.isEmpty`：LRCLIB 有时回一个**空字符串**的 syncedLyrics，
        // 那会做出一个"0 行但标记为 timeSynced"的结果（听歌页上就是一片空白），
        // 落到下面按 plainLyrics 取才是对的。
        if let syncedLyrics = song.syncedLyrics, !syncedLyrics.isEmpty {
            // 不能用 `components(separatedBy: "\n").dropLast` —— 那假定源以换行收束；
            // 没有尾换行的响应里**最后一行真歌词会被静默丢掉**（理由与判据见 `LyricsLineSplitting`）。
            let lines = LyricsLineSplitting.splitDroppingTrailingNewline(syncedLyrics)
            writeDebugLog("[LRCLIB] Synced lyrics — \(lines.count) line(s)")
            return LyricsDto(
                lines: mapSyncedLyricsLines(lines),
                timeSynced: true,
                romanization: lines.canBeRomanized ? .canBeRomanized : .original
            )
        }

        guard let plainLyrics = song.plainLyrics else {
            throw LyricsError.decodingError
        }

        // 同上 —— 别再无条件 `dropLast`。
        let lines = LyricsLineSplitting.splitDroppingTrailingNewline(plainLyrics)
        writeDebugLog("[LRCLIB] Plain lyrics — \(lines.count) line(s)")
        return LyricsDto(
            lines: lines.map { content in LyricsLineDto(content: content) },
            timeSynced: false,
            romanization: lines.canBeRomanized ? .canBeRomanized : .original
        )
    }
}
