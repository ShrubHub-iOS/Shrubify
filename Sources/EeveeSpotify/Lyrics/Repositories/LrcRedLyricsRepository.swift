import Foundation

struct LrcRedLyricsRepository: LyricsRepository {
    private struct MatchResponse: Decodable {
        let hits: [Match]
    }

    private struct Match: Decodable {
        let isrc: String
        let title: String
        let artist: String
        let duration: Double?
    }

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        if let isrc = query.isrc, let result = try getLyrics(isrc: isrc) { return result }
        guard !query.title.isEmpty, !query.primaryArtist.isEmpty else { throw LyricsError.noSuchSong }
        var url = URLComponents()
        url.scheme = "https"
        url.host = "lrc.red"
        url.path = "/match.json"
        url.queryItems = [
            URLQueryItem(name: "track", value: query.title), URLQueryItem(name: "artist", value: query.primaryArtist)
        ]
        if let album = query.albumTitle { url.queryItems?.append(URLQueryItem(name: "album", value: album)) }
        if let duration = query.durationMs, duration > 0 {
            url.queryItems?.append(URLQueryItem(name: "duration", value: String(Double(duration) / 1000)))
        }
        guard let request = url.url else { throw LyricsError.invalidSource }
        let response = try JSONDecoder().decode(MatchResponse.self, from: LyricsSourceHTTP.getData(request, tag: "lrc.red"))
        let match = response.hits.first { candidate in
            let durationMs = candidate.duration.flatMap { value in
                value.isFinite && (0...86_400).contains(value) ? Int((value * 1000).rounded()) : nil
            }
            return LyricsMatch.titlesMatch(candidate.title, anyOf: [query.title] + query.titleVariants)
                && query.allArtistNames.contains { LyricsMatch.sameArtist(candidate.artist, $0) }
                && LyricsMatch.lengthMatches(durationMs, query.durationMs, slackMs: 4500)
        }
        guard let match, let result = try getLyrics(isrc: match.isrc) else { throw LyricsError.noSuchSong }
        return result
    }

    private func getLyrics(isrc: String) throws -> LyricsDto? {
        let identifier = isrc.uppercased()
        guard identifier.range(of: #"^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$"#, options: .regularExpression) != nil,
              let url = URL(string: "https://lrc.red/s/\(identifier).ttml") else { return nil }
        guard let file = LyricsSourceHTTP.getText(url, headers: ["Accept": "application/ttml+xml"], tag: "lrc.red") else {
            try LyricsRequestBudget.check()
            return nil
        }
        let parsed = try AmllTtmlParser.parse(file)
        var dto = AmllLyricsMapper.makeDto(parsed, logTag: "lrc.red")
        guard !dto.lines.isEmpty else { return nil }
        dto.providerName = "lrc.red"
        dto.providerURL = URL(string: "https://lrc.red/")
        return dto
    }
}
