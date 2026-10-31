#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <math.h>
#import <string.h>

// Vitrine Shared/Lyrics/KaraokeSource.x confirms seekTo: takes seconds on SPTEsperantoPlayer.
// Restrict calls to the existing seconds-based seek names with a verified ABI.
// Do not call integer/millisecond or callback-taking variants with a double.
BOOL ShrubSeekPlaybackSeconds(id target, double seconds) {
    if (!target || !isfinite(seconds) || seconds < 0) return NO;
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
}
