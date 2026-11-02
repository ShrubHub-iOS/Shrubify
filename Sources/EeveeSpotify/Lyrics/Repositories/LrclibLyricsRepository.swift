import Foundation

class LrclibLyricsRepository: LyricsRepository {
    private let settingsLock = NSLock()
    private var configuredApiUrl: String
    var apiUrl: String {
        get { settingsLock.lock(); defer { settingsLock.unlock() }; return configuredApiUrl }
        set { settingsLock.lock(); configuredApiUrl = newValue; settingsLock.unlock() }
    }
    private let session: URLSession

    private init(apiUrl: String) {
        self.configuredApiUrl = apiUrl
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Shrubify v\(EeveeSpotify.version) https://github.com/zoinkdoggie94/Shrubify"
        ]
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.waitsForConnectivity = false

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
            throw LyricsError.decodingError
        }

        var request = URLRequest(url: url)


        request.setValue(
            "Shrubify v\(EeveeSpotify.version) https://github.com/zoinkdoggie94/Shrubify",
            forHTTPHeaderField: "User-Agent"
        )

        let semaphore = DispatchSemaphore(value: 0)
        var data: Data?
        var error: Error?

        let task = session.dataTask(with: request) { responseData, _, err in
            error = err
            data = responseData
            semaphore.signal()
        }

        LyricsRequestContext.resume(task)
        semaphore.wait()

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
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            writeDebugLog("[LRCLIB] Decode error for \(trackName)/\(artistName): \(error). Body: \(body.prefix(300))")
            throw error
        }
    }
    
    private func mapSyncedLyricsLines(_ lines: [String]) -> [LyricsLineDto] {
        lines.compactMap { line in
            guard let parsed = LyricsTextParser.timestampedLine(line) else { return nil }
            return LyricsLineDto(content: parsed.content.lyricsNoteIfEmpty, offsetMs: parsed.milliseconds)
        }
    }

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        let song: LrclibSong

        do {
            song = try getSong(trackName: query.title, artistName: query.primaryArtist)
        } catch {
            let strippedTitle = query.title.strippedTrackTitle
            guard strippedTitle != query.title else { throw LyricsError.noSuchSong }
            do {
                song = try getSong(trackName: strippedTitle, artistName: query.primaryArtist)
            } catch {
                throw LyricsError.noSuchSong
            }
        }

        if song.instrumental {
            return LyricsDto(
                lines: [],
                timeSynced: false,
                romanization: .original,
                instrumental: true
            )
        }

        if let syncedLyrics = song.syncedLyrics, !syncedLyrics.isEmpty {
            let lines = LyricsTextParser.lines(syncedLyrics)
            return LyricsDto(
                lines: mapSyncedLyricsLines(lines),
                timeSynced: true,
                romanization: lines.canBeRomanized ? .canBeRomanized : .original
            )
        }
        
        guard let plainLyrics = song.plainLyrics, !plainLyrics.isEmpty else {
            return LyricsDto(
                lines: [],
                timeSynced: false,
                romanization: .original
            )
        }
        
        let lines = LyricsTextParser.lines(plainLyrics)
        
        return LyricsDto(
            lines: lines.map { content in LyricsLineDto(content: content) },
            timeSynced: false,
            romanization: lines.canBeRomanized ? .canBeRomanized : .original
        )
    }
}
