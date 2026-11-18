import Foundation
import EeveeSpotifyC
import Orion
import UIKit
import ObjectiveC.runtime

struct KaraokeLivePlayerGroup: HookGroup {}
struct KaraokeObservableGroup: HookGroup {}

private let karaokeObserver = ShrubifyKaraokeObserver()
private let observedKaraokePlayers = NSHashTable<AnyObject>.weakObjects()

@objc final class ShrubifyKaraokeObserver: NSObject {
    @objc func didChangeState(_ state: AnyObject) { KaraokeSeek.observe(state) }
    @objc func playerStateDidChange(_ state: AnyObject) { KaraokeSeek.observe(state) }
    @objc func player(_ player: AnyObject, stateDidChange state: AnyObject) { KaraokeSeek.observe(state) }
    @objc func player(_ player: AnyObject, stateDidChange state: AnyObject, fromState old: AnyObject) { KaraokeSeek.observe(state) }
    @objc func player(_ player: AnyObject, didEncounterError error: AnyObject) {}
    @objc func player(_ player: AnyObject, didMoveToRelativeTrack index: Int) {}
    @objc func player(_ player: AnyObject, queueDidChange queue: AnyObject) {}
}

private func captureKaraokePlayer(_ player: AnyObject) {
    KaraokeSeek.captureLivePlayer(player)
    DispatchQueue.main.async {
        if !observedKaraokePlayers.contains(player) {
            observedKaraokePlayers.add(player)
            _ = ShrubRegisterPlaybackObserver(player, karaokeObserver)
        }
    }
}

class KaraokeLivePlayerHook: ClassHook<NSObject> {
    typealias Group = KaraokeLivePlayerGroup
    static let targetName = "SPTEsperantoPlayer"
    func state() -> AnyObject {
        let state = orig.state()
        captureKaraokePlayer(target)
        KaraokeSeek.observe(state)
        return state
    }
}

class KaraokeObservableHook: ClassHook<NSObject> {
    typealias Group = KaraokeObservableGroup
    static var targetName: String {
        NSClassFromString("SPTPlayerServiceImplementation") != nil ? "SPTPlayerServiceImplementation"
            : "_TtC17Player_CommonImpl30SPTPlayerServiceImplementation"
    }
    func provideStateObservable() -> AnyObject {
        let player = orig.provideStateObservable()
        captureKaraokePlayer(player)
        return player
    }
}

private func hasObjectGetter(_ name: String, _ getter: String) -> Bool {
    guard let cls = NSClassFromString(name) as? NSObject.Type,
          let method = class_getInstanceMethod(cls, NSSelectorFromString(getter)),
          method_getNumberOfArguments(method) == 2,
          let type = method_copyReturnType(method) else { return false }
    defer { free(type) }
    return type.pointee == 64 // '@': do not hook a scalar as an object.
}

func activateKaraokePlaybackCapture() {
    if hasObjectGetter(KaraokeLivePlayerHook.targetName, "state") { KaraokeLivePlayerGroup().activate() }
    if hasObjectGetter(KaraokeObservableHook.targetName, "provideStateObservable") { KaraokeObservableGroup().activate() }
}
