#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
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
    @try {
        SEL selector = NSSelectorFromString(name);
        if (![object respondsToSelector:selector]) return nil;
        NSMethodSignature *signature = [object methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (NSException *exception) { return nil; }
}

// The legacy scroll controller exposes object ivars rather than getters.
// Missing/renamed/scalar ivars mean "no current track", never a forced read.
static id ShrubLegacyObject(id object, NSString *name) {
    id value = ShrubPlaybackObject(object, name);
    if (value || !object) return value;
    for (NSString *key in @[name, [@"_" stringByAppendingString:name]]) {
        Ivar ivar = class_getInstanceVariable(object_getClass(object), key.UTF8String);
        const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
        if (type && type[0] == '@') return object_getIvar(object, ivar);
    }
    return nil;
}

id ShrubReadCurrentTrack(id player, id legacyController) {
    @try {
        return ShrubPlaybackObject(player, @"currentTrack") ?:
            ShrubLegacyObject(ShrubLegacyObject(legacyController, @"scrollViewModel"), @"loadedTrack");
    } @catch (NSException *exception) { return nil; }
}

static NSString *ShrubString(id value) {
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

NSString *ShrubTrackIdentifier(id track) {
    @try {
        id uri = ShrubPlaybackObject(track, @"URI");
        NSString *identifier = ShrubString(ShrubPlaybackObject(uri, @"spt_trackIdentifier"));
        if (identifier) return identifier;
        NSString *string = ShrubString(uri) ?: ShrubString(ShrubPlaybackObject(uri, @"absoluteString"));
        NSArray *parts = [string componentsSeparatedByString:@":"];
        if (parts.count == 3 && [parts[0] isEqual:@"spotify"] &&
            ([parts[1] isEqual:@"track"] || [parts[1] isEqual:@"episode"])) return ShrubString(parts.lastObject);
        return nil;
    } @catch (NSException *exception) { return nil; }
}

// Read an immutable set of facts for one track. A missing/throwing optional
// getter must not cost us the other fields (or require guessing a build number).
NSDictionary *ShrubReadTrackMetadata(id track) {
    if (!track) return nil;
    @try {
        id rawMetadata = ShrubPlaybackObject(track, @"metadata");
        NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
        if ([rawMetadata isKindOfClass:NSDictionary.class]) {
            for (id key in rawMetadata) {
                if (![key isKindOfClass:NSString.class]) continue;
                id value = rawMetadata[key];
                if ([value isKindOfClass:NSString.class]) metadata[key] = value;
                else if ([key hasPrefix:@"duration"] && [value isKindOfClass:NSNumber.class]) metadata[key] = [value stringValue];
            }
        }
        NSString *title = ShrubString(ShrubPlaybackObject(track, @"trackTitle")) ?: ShrubString(metadata[@"title"]);
        if (!title) return nil;
        NSString *artist = ShrubString(ShrubPlaybackObject(track, @"artistName")) ?:
            ShrubString(ShrubPlaybackObject(track, @"artistTitle")) ?: metadata[@"artist_name"];
        NSString *color = ShrubString(metadata[@"extracted_color"]) ?: ShrubString(ShrubPlaybackObject(track, @"extractedColorHex"));
        return @{@"title": title, @"artist": artist ?: @"", @"metadata": metadata,
                 @"identifier": ShrubTrackIdentifier(track) ?: @"", @"color": color ?: @""};
    } @catch (NSException *exception) { return nil; }
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
        id track = ShrubPlaybackObject(state, @"track") ?: ShrubPlaybackObject(state, @"currentTrack");
        id uri = ShrubPlaybackObject(track, @"URI");
        if ([uri isKindOfClass:NSURL.class]) uri = [uri absoluteString];
        else if (![uri isKindOfClass:NSString.class]) uri = ShrubPlaybackObject(uri, @"absoluteString");
        if ([uri isKindOfClass:NSString.class]) facts[@"uri"] = uri;
        return facts;
    } @catch (NSException *exception) { return nil; }
}

NSDictionary *ShrubReadLivePlayback(id player) {
    @try {
        NSDictionary *facts = ShrubPlaybackFacts(ShrubPlaybackObject(player, @"state"));
        // StatefulPlayer exposes position directly; SPTEsperantoPlayer exposes state.
        return facts ?: ShrubPlaybackFacts(player);
    }
    @catch (NSException *exception) { return nil; }
}

BOOL ShrubSetPlaybackPaused(id player, BOOL paused) {
    @try {
        for (NSString *name in paused ? @[@"pause:", @"pause"] : @[@"resume:", @"resume"]) {
            SEL selector = NSSelectorFromString(name);
            if (![player respondsToSelector:selector]) continue;
            NSMethodSignature *sig = [player methodSignatureForSelector:selector];
            BOOL hasOptions = [name hasSuffix:@":"];
            if (!sig || sig.numberOfArguments != (hasOptions ? 3 : 2) ||
                (hasOptions && [sig getArgumentTypeAtIndex:2][0] != '@') ||
                (sig.methodReturnType[0] != '@' && sig.methodReturnType[0] != 'v')) continue;
            NSInvocation *call = [NSInvocation invocationWithMethodSignature:sig];
            call.target = player; call.selector = selector;
            if (hasOptions) { id options = nil; [call setArgument:&options atIndex:2]; }
            [call invoke];
            return YES;
        }
        return NO;
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
