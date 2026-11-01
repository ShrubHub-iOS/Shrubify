#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <math.h>
#import <string.h>

// Vitrine Shared/Lyrics/KaraokeSource.x confirms seekTo: takes seconds on SPTEsperantoPlayer.
// Restrict calls to the existing seconds-based seek names with a verified ABI.
// Do not call integer/millisecond or callback-taking variants with a double.
BOOL ShrubSeekPlaybackSeconds(id target, double seconds) {
    if (!target || !isfinite(seconds) || seconds < 0) return NO;
    @try {
    for (NSString *name in @[@"seekTo:"]) {
        SEL selector = NSSelectorFromString(name);
        if (![target respondsToSelector:selector]) continue;
        NSMethodSignature *signature = [target methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments != 3 ||
            strcmp([signature getArgumentTypeAtIndex:2], @encode(double)) != 0 ||
            (strcmp(signature.methodReturnType, @encode(void)) != 0 && strcmp(signature.methodReturnType, @encode(id)) != 0)) continue;
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = target;
        invocation.selector = selector;
        [invocation setArgument:&seconds atIndex:2];
        [invocation invoke];
        return YES;
    }
    return NO;
    } @catch (NSException *exception) { return NO; }
}

// Read the native clock rather than relying on observer arrival times. Every
// getter is checked for its ABI and exceptions stay on the Objective-C side.
static id ShrubPlaybackObject(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (![object respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSNumber *ShrubPlaybackNumber(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (![object respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2) return nil;
    const char *type = signature.methodReturnType;
    if (strcmp(type, @encode(double)) == 0) {
        double value = ((double (*)(id, SEL))objc_msgSend)(object, selector);
        return isfinite(value) ? @(value) : nil;
    }
    if (strcmp(type, @encode(BOOL)) == 0 || strcmp(type, "c") == 0) {
        return @(((BOOL (*)(id, SEL))objc_msgSend)(object, selector));
    }
    return nil;
}

NSDictionary *ShrubPlaybackFacts(id state) {
    @try {
        NSNumber *paused = ShrubPlaybackNumber(state, @"isPaused");
        NSNumber *position = paused.boolValue ? ShrubPlaybackNumber(state, @"positionAsOfTimestamp") : nil;
        position = position ?: ShrubPlaybackNumber(state, @"position");
        if (!position) return nil;
        NSMutableDictionary *facts = [@{@"position": position} mutableCopy];
        if (paused) facts[@"paused"] = paused;
        else {
            NSNumber *playing = ShrubPlaybackNumber(state, @"isPlaying");
            if (playing) facts[@"paused"] = @(!playing.boolValue);
        }
        NSNumber *duration = ShrubPlaybackNumber(state, @"duration");
        NSNumber *speed = ShrubPlaybackNumber(state, @"playbackSpeed");
        if (duration) facts[@"duration"] = duration;
        if (speed) facts[@"speed"] = speed;
        id track = ShrubPlaybackObject(state, @"track");
        id uri = ShrubPlaybackObject(track, @"URI");
        if ([uri isKindOfClass:NSURL.class]) uri = [uri absoluteString];
        if ([uri isKindOfClass:NSString.class]) facts[@"uri"] = uri;
        return facts;
    } @catch (NSException *exception) { return nil; }
}

NSDictionary *ShrubReadLivePlayback(id player) {
    @try { return ShrubPlaybackFacts(ShrubPlaybackObject(player, @"state")); }
    @catch (NSException *exception) { return nil; }
}

BOOL ShrubSetPlaybackPaused(id player, BOOL paused) {
    @try {
        SEL selector = NSSelectorFromString(paused ? @"pause:" : @"resume:");
        if (![player respondsToSelector:selector]) return NO;
        NSMethodSignature *sig = [player methodSignatureForSelector:selector];
        if (!sig || sig.numberOfArguments != 3 || [sig getArgumentTypeAtIndex:2][0] != '@' ||
            (sig.methodReturnType[0] != '@' && sig.methodReturnType[0] != 'v')) return NO;
        NSInvocation *call = [NSInvocation invocationWithMethodSignature:sig];
        call.target = player;
        call.selector = selector;
        id options = nil;
        [call setArgument:&options atIndex:2];
        [call invoke];
        return YES;
    } @catch (NSException *exception) { return NO; }
}

BOOL ShrubRegisterPlaybackObserver(id player, id observer) {
    @try {
        SEL selector = NSSelectorFromString(@"addPlayerObserver:");
        if (![player respondsToSelector:selector]) return NO;
        NSMethodSignature *sig = [player methodSignatureForSelector:selector];
        if (!sig || sig.numberOfArguments != 3 || [sig getArgumentTypeAtIndex:2][0] != '@') return NO;
        NSInvocation *call = [NSInvocation invocationWithMethodSignature:sig];
        call.target = player;
        call.selector = selector;
        [call setArgument:&observer atIndex:2];
        [call invoke];
        return YES;
    } @catch (NSException *exception) { return NO; }
}
