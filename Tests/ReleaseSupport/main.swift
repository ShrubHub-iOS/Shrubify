import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
func check(_ value: @autoclosure () -> Bool, _ name: String) {
    guard value() else { fatalError("FAILED: " + name) }
}
// Active release regressions: task buffering, account policy and Replay boundaries.
check(!ServerSidedFeaturePolicy.shouldOverwriteResolvedConfiguration(requested: true), "legacy preference cannot replace account navigation configuration")
for route in ["https://spclient.wg.spotify.com/esperanto/metadata/get", "https://spclient.wg.spotify.com/esperanto/load"] {
    check(!URL(string: route)!.isAdRelated, "ordinary Esperanto request permitted")
}
check(URL(string: "https://spclient.wg.spotify.com/esperanto/ads/slot")!.isAdRelated, "known ad route still classified")
let sessionA = URLSession(configuration: .ephemeral)
let sessionB = URLSession(configuration: .ephemeral)
let taskA = sessionA.dataTask(with: URL(string: "https://example.com/a")!)
let taskB = sessionB.dataTask(with: URL(string: "https://example.com/b")!)
check(taskA.taskIdentifier == taskB.taskIdentifier, "fixture has colliding session-local IDs")
let buffers = URLSessionHelper.shared
buffers.setReplay(Data([1]), for: taskA)
buffers.setReplay(Data([2]), for: taskB)
check(buffers.obtainReplay(for: taskB) == Data([2]), "replay isolated across sessions")
check(buffers.obtainReplay(for: taskA) == Data([1]), "other session cannot consume replay")
buffers.setOrAppend(Data([1]), for: taskA); buffers.setOrAppend(Data([2]), for: taskA)
check(buffers.obtainData(for: taskA) == Data([1, 2]), "body assembled in order")
check(buffers.obtainData(for: taskA) == nil, "terminal read releases body")
buffers.setOrAppend(Data([3]), for: taskA); buffers.setReplay(Data([4]), for: taskA)
buffers.discardData(for: taskA)
check(buffers.obtainData(for: taskA) == nil && buffers.obtainReplay(for: taskA) == nil, "discard removes all request state")
sessionA.invalidateAndCancel(); sessionB.invalidateAndCancel()
check(ReplayPlaybackBoundary.didRepeat(previous: 235, current: 5, duration: 240, elapsed: 10, rate: 1), "natural Repeat One wrap counted")
check(!ReplayPlaybackBoundary.didRepeat(previous: 100, current: 5, duration: 240, elapsed: 10, rate: 1), "ordinary backward seek does not count as repeat")
check(!ReplayPlaybackBoundary.didRepeat(previous: 235, current: 5, duration: 240, elapsed: 90, rate: 1), "background gap not backfilled as a repeat")
print("V4 release reliability regression checks passed")
