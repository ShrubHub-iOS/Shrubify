import Foundation

enum LyricsTrackMetadata {
    private static let lock = NSLock()
    private static var tracks: [String: (title: String, artist: String)] = [:]
    private static var lastId: String?
    static func set(trackId: String, title: String, artist: String) {
        lock.lock(); defer { lock.unlock() }
        if tracks.count >= 16, tracks[trackId] == nil { tracks.removeAll() }
        tracks[trackId] = (title, artist); lastId = trackId
    }
    static func get(trackId: String) -> (title: String, artist: String)? {
        lock.lock(); defer { lock.unlock() }; return tracks[trackId]
    }
    static var current: (id: String, title: String, artist: String)? {
        lock.lock(); defer { lock.unlock() }
        guard let id = lastId, let value = tracks[id] else { return nil }
        return (id, value.title, value.artist)
    }
}
var capturedTrackTitle: String? { LyricsTrackMetadata.current?.title }
var capturedArtistName: String? { LyricsTrackMetadata.current?.artist }
var capturedTrackId: String? { LyricsTrackMetadata.current?.id }

// Function to fetch track details using Spotify API if we have a token
func fetchTrackDetails(trackId: String, token: String) -> (title: String, artist: String)? {
    let urlString = "https://api.spotify.com/v1/tracks/\(trackId)"
    guard let url = URL(string: urlString) else { return nil }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 3.0
    
    var result: (String, String)?
    let semaphore = DispatchSemaphore(value: 0)
    
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 3
    config.timeoutIntervalForResource = 3
    let session = URLSession(configuration: config)
    defer { session.finishTasksAndInvalidate() }
    let task = session.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        guard let data = data, error == nil else { return }
        
        // Simple JSON parsing
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = json["name"] as? String,
           let artists = json["artists"] as? [[String: Any]],
           let firstArtist = artists.first,
           let artistName = firstArtist["name"] as? String {
            result = (name, artistName)
        }
    }
    
    LyricsRequestContext.resume(task)
    semaphore.wait()
    
    return result
}
