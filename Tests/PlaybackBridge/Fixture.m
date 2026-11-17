#import "PlaybackBridge.h"
@interface ShrubFixtureState : NSObject
@property double position;
@property double positionAsOfTimestamp;
@property double duration;
@property double playbackSpeed;
@property BOOL isPaused;
@end
@implementation ShrubFixtureState
@end
@interface ShrubFixturePlayer : NSObject
@property (nonatomic, strong) ShrubFixtureState *state;
@end
@implementation ShrubFixturePlayer
- (id)seekTo:(double)seconds {
    self.state.position = seconds;
    self.state.positionAsOfTimestamp = seconds;
    return nil;
}
- (id)pause:(id)options { self.state.isPaused = YES; return nil; }
- (id)resume:(id)options { self.state.isPaused = NO; return nil; }
- (void)addPlayerObserver:(id)observer {}
@end
@interface ShrubThrowingPlayer : NSObject
@end
@implementation ShrubThrowingPlayer
- (id)state { @throw [NSException exceptionWithName:@"Unavailable" reason:@"test" userInfo:nil]; }
- (id)seekTo:(double)seconds { @throw [NSException exceptionWithName:@"Unavailable" reason:@"test" userInfo:nil]; }
- (void)addPlayerObserver:(id)observer { @throw [NSException exceptionWithName:@"Unavailable" reason:@"test" userInfo:nil]; }
@end
id ShrubTestPlayer(void) {
    ShrubFixturePlayer *player = [ShrubFixturePlayer new];
    player.state = [ShrubFixtureState new];
    player.state.position = 20;
    player.state.positionAsOfTimestamp = 10;
    player.state.duration = 240;
    player.state.playbackSpeed = 1;
    player.state.isPaused = YES;
    return player;
}
id ShrubTestThrowingPlayer(void) { return [ShrubThrowingPlayer new]; }

@interface ShrubNoArgumentPlayer : NSObject
@property BOOL paused;
@end
@implementation ShrubNoArgumentPlayer
- (void)pause { self.paused = YES; }
- (void)resume { self.paused = NO; }
@end
@interface ShrubIntegerSeekPlayer : NSObject
@end
@implementation ShrubIntegerSeekPlayer
- (void)seekTo:(NSInteger)value { [NSException raise:@"InvalidABI" format:@"Integer seek must never be invoked as a double"]; }
@end
id ShrubTestNoArgumentPlayer(void) { return [ShrubNoArgumentPlayer new]; }
id ShrubTestIntegerSeekPlayer(void) { return [ShrubIntegerSeekPlayer new]; }
id ShrubTestLongPodcast(void) {
    ShrubFixturePlayer *player = ShrubTestPlayer();
    player.state.duration = 10800;
    player.state.positionAsOfTimestamp = 7200;
    return player;
}
