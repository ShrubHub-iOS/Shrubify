import Foundation

struct LyricsPlusRepository: LyricsRepository {
    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        guard !query.title.isEmpty, !query.primaryArtist.isEmpty else { throw LyricsError.noSuchSong }
        var url = URLComponents()
        url.scheme = "https"
        url.host = "lyricsplus.prjktla.my.id"
        url.path = "/v2/lyrics/get"
        url.queryItems = [
            URLQueryItem(name: "title", value: query.title), URLQueryItem(name: "artist", value: query.primaryArtist)
        ]
        if let album = query.albumTitle { url.queryItems?.append(URLQueryItem(name: "album", value: album)) }
        if let duration = query.durationMs, duration > 0 {
            url.queryItems?.append(URLQueryItem(name: "duration", value: String(Double(duration) / 1000)))
        }
        if let isrc = query.isrc { url.queryItems?.append(URLQueryItem(name: "isrc", value: isrc)) }
        guard let request = url.url else { throw LyricsError.invalidSource }
        let payload = try JSONDecoder().decode(LyricsPlusPayload.self,
                                               from: LyricsSourceHTTP.getData(request, tag: "LyricsPlus"))
        guard payload.matches(query) else { throw LyricsError.trackMismatch }
        let lines = payload.lines
        guard !lines.isEmpty else { throw LyricsError.noSuchSong }
        return LyricsDto(lines: lines, timeSynced: payload.isTimed && lines.contains { $0.offsetMs != nil },
                         romanization: lines.map(\.content).canBeRomanized ? .canBeRomanized : .original,
                         languageCode: payload.language, providerName: "LyricsPlus",
                         providerURL: URL(string: "https://github.com/ibratabian17/LyricsPlus"))
    }
}
