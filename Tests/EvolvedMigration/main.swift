import Foundation

extension UserDefaults { static var container: UserDefaults { .standard } }
let suite = "ShrubifyMigrationFixture-" + UUID().uuidString
let preferences = UserDefaults(suiteName: suite)!
defer { preferences.removePersistentDomain(forName: suite) }
preferences.set(5, forKey: "lyricsSource")
preferences.set("fixture-client-key", forKey: "spicyLyricsApiKey")
preferences.set("fixture-token", forKey: "musixmatchToken")
preferences.set(0x113355, forKey: "eeveeAccent")
preferences.set(Data([1, 2]), forKey: "ShrubifySavedLayouts3")
ShrubifyEvolvedMigration.apply(to: preferences)
assert(preferences.integer(forKey: "lyricsSource") == 5)
assert(preferences.string(forKey: "spicyLyricsApiKey") == "fixture-client-key")
assert(preferences.string(forKey: "musixmatchToken") == "fixture-token")
assert(preferences.integer(forKey: "accentColorRGB") == 0x113355)
assert(preferences.data(forKey: "ShrubifySavedLayouts3") == Data([1, 2]))
assert(!preferences.bool(forKey: "ShrubifyReplayEnabled3"), "UI migration must not opt users into history")
assert(preferences.bool(forKey: "nowPlayingIOS27"))
assert(preferences.bool(forKey: "miniBarGlass"))
preferences.set(false, forKey: "nowPlayingIOS27")
preferences.set(0x998877, forKey: "accentColorRGB")
ShrubifyEvolvedMigration.apply(to: preferences)
assert(!preferences.bool(forKey: "nowPlayingIOS27"), "Repeated launch must respect the chosen player")
assert(preferences.integer(forKey: "accentColorRGB") == 0x998877)
print("Evolved appearance migration and credential-preservation checks passed")
