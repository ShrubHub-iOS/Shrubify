import Orion
import Intents

class INMediaItemHook: ClassHook<INMediaItem> {
    typealias Group = PremiumUIHooksGroup

    func identifier() -> String {
        let identifier = orig.identifier()
        guard identifier.hasPrefix("spotify:play-command:") else { return identifier }
        let encoded = String(identifier.dropFirst("spotify:play-command:".count))
        guard let data = Data(base64Encoded: encoded),
              var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let feedback = json["feedback_details"] as? [String: Any],
              feedback["restriction"] as? String == "play-as-radio",
              var context = json["context"] as? [String: Any],
              let url = context["url"] as? String else { return identifier }
        context["url"] = url.removeMatches(":station")
        json["context"] = context
        guard let result = try? JSONSerialization.data(withJSONObject: json) else { return identifier }
        return "spotify:play-command:" + result.base64EncodedString()
    }
}
