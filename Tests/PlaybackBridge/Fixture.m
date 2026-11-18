#import "PlaybackBridge.h"
@interface ShrubDirectTrack : NSObject
@end
@implementation ShrubDirectTrack
- (NSURL *)URI { return [NSURL URLWithString:@"spotify:track:direct-clock"]; }
@end
@interface ShrubDirectPlayer : NSObject
@end
@implementation ShrubDirectPlayer
- (double)position { return 24; }
- (double)duration { return 220; }
- (BOOL)isPaused { return YES; }
- (id)currentTrack { return [ShrubDirectTrack new]; }
@end
@interface ShrubScalarPositionPlayer : NSObject
@end
@implementation ShrubScalarPositionPlayer
- (NSInteger)position { [NSException raise:@"WrongClockABI" format:@"Must not call an integer getter as double"]; return 0; }
@end
id ShrubTestDirectPlayer(void) { return [ShrubDirectPlayer new]; }
id ShrubTestScalarPositionPlayer(void) { return [ShrubScalarPositionPlayer new]; }
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

@interface ShrubModernTrack : NSObject
@end
@implementation ShrubModernTrack
- (NSString *)trackTitle { return @"Modern track"; }
- (NSString *)artistName { return @"Modern artist"; }
- (NSString *)artistTitle { [NSException raise:@"UnsupportedLegacySelector" format:@"Modern playback must not call artistTitle"]; return nil; }
- (NSURL *)URI { return [NSURL URLWithString:@"spotify:track:modern"]; }
- (NSDictionary *)metadata { return @{@"album_uri": @"spotify:album:fixture", @"bad_field": @42, @"duration_ms": @28000,
                                     @"artist_name:1": @"Guest", @"title": @"Localized title"}; }
@end
@interface ShrubLegacyTrack : NSObject
@end
@implementation ShrubLegacyTrack
- (NSString *)trackTitle { return @"Legacy track"; }
- (NSString *)artistName { [NSException raise:@"Unavailable" format:@"Old build"]; return nil; }
- (NSString *)artistTitle { return @"Legacy artist"; }
- (NSString *)extractedColorHex { return @"abcdef"; }
- (NSInteger)URI { [NSException raise:@"WrongABI" format:@"Not an object getter"]; return 0; }
@end
@interface ShrubThrowingTrack : NSObject
@end
@implementation ShrubThrowingTrack
- (NSString *)trackTitle { [NSException raise:@"UnavailableTrack" format:@"Track not ready"]; return nil; }
@end
@interface ShrubScalarTrack : NSObject
@end
@implementation ShrubScalarTrack
- (double)trackTitle { [NSException raise:@"WrongABI" format:@"Scalar getter must not be invoked as an object"]; return 0; }
@end
id ShrubTestModernTrack(void) { return [ShrubModernTrack new]; }
id ShrubTestLegacyTrack(void) { return [ShrubLegacyTrack new]; }
id ShrubTestThrowingTrack(void) { return [ShrubThrowingTrack new]; }
id ShrubTestScalarTrack(void) { return [ShrubScalarTrack new]; }

@interface ShrubLegacyTrackModel : NSObject { id loadedTrack; }
@end
@implementation ShrubLegacyTrackModel
- (instancetype)init { if ((self = [super init])) loadedTrack = ShrubTestLegacyTrack(); return self; }
@end
@interface ShrubLegacyController : NSObject { id _scrollViewModel; }
@end
@implementation ShrubLegacyController
- (instancetype)init { if ((self = [super init])) _scrollViewModel = [ShrubLegacyTrackModel new]; return self; }
@end
id ShrubTestLegacyController(void) { return [ShrubLegacyController new]; }
