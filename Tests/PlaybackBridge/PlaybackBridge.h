#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
BOOL ShrubSeekPlaybackSeconds(id target, double seconds);
NSDictionary *_Nullable ShrubPlaybackFacts(id state);
NSDictionary *_Nullable ShrubReadLivePlayback(id player);
BOOL ShrubSetPlaybackPaused(id player, BOOL paused);
BOOL ShrubRegisterPlaybackObserver(id player, id observer);
id ShrubTestPlayer(void);
id ShrubTestThrowingPlayer(void);

NS_ASSUME_NONNULL_END
