// Derived from Vitrine tweak/Sources/Core/SGGlass.m, GPL-3.0.
// Upstream: https://github.com/My-Name-Is-Jeff/vitrine
// Kept to one narrowly scoped material/shaping adapter to avoid colliding Spotify hooks.
#import "VitrineGlass.h"

UIVisualEffect *ShrubVitrineGlassEffect(void) {
    // Vitrine uses the factory: -init alone leaves the iOS 26 material unresolved.
    // A selector check also keeps this safe when a simulator or an older OS loads the tweak.
    Class glass = NSClassFromString(@"UIGlassEffect");
    if ([glass respondsToSelector:@selector(effectWithStyle:)]) {
        return [glass effectWithStyle:0];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
}

void ShrubVitrineShapeGlass(UIView *view, CGFloat radius, BOOL capsule) {
    if (!view) return;
    static Class config, cornerRadius;
    static BOOL capsules, uniform;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        config = NSClassFromString(@"UICornerConfiguration");
        cornerRadius = NSClassFromString(@"UICornerRadius");
        capsules = [config respondsToSelector:@selector(capsuleConfiguration)];
        uniform = [config respondsToSelector:@selector(configurationWithUniformRadius:)]
            && [cornerRadius respondsToSelector:@selector(fixedRadius:)];
    });
    id shape = nil;
    if (config && [view respondsToSelector:@selector(setCornerConfiguration:)]) {
        if (capsule && capsules) {
            shape = [config capsuleConfiguration];
        } else if (uniform) {
            shape = [config configurationWithUniformRadius:[cornerRadius fixedRadius:radius]];
        }
    }
    if (shape) {
        [view setCornerConfiguration:shape];
        view.clipsToBounds = NO;
    } else {
        view.layer.cornerRadius = capsule ? view.bounds.size.height / 2 : radius;
        view.layer.cornerCurve = kCACornerCurveContinuous;
        view.clipsToBounds = YES;
    }
}
