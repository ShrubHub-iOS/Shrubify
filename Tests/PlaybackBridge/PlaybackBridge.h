#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
BOOL ShrubSeekPlaybackSeconds(id target, double seconds);
NSDictionary *_Nullable ShrubPlaybackFacts(id state);
NSDictionary *_Nullable ShrubReadTrackMetadata(id track);
NSDictionary *_Nullable ShrubReadLivePlayback(id player);
BOOL ShrubSetPlaybackPaused(id player, BOOL paused);
BOOL ShrubRegisterPlaybackObserver(id player, id observer);
id ShrubTestPlayer(void);
id ShrubTestThrowingPlayer(void);

id ShrubTestNoArgumentPlayer(void);
id ShrubTestIntegerSeekPlayer(void);
id ShrubTestLongPodcast(void);
id ShrubTestModernTrack(void);
id ShrubTestLegacyTrack(void);
id ShrubTestThrowingTrack(void);
id ShrubTestScalarTrack(void);
NS_ASSUME_NONNULL_END
