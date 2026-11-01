#import <UIKit/UIKit.h>
#import "VitrineGlass.h"

NS_ASSUME_NONNULL_BEGIN

void EeveeSBInvokeSeekDouble(id target, SEL selector, double argument);
NSString *EeveeJBRootPath(NSString *path);
BOOL EeveeSetMainInfoValue(NSString *key, id value);
UIImage *_Nullable EeveeRenderTemplate(UIView *view);
UIImage *_Nullable EeveeEncoreIconImage(UIView *iconView, BOOL active);
BOOL EeveeFireTap(UIView *root);
int EeveeInstallColorSwaps(BOOL amoled, NSInteger accentRGB);
void EeveeColorSwapStats(long *grey, long *green, long *uiColor);
BOOL EeveePinSetter(id object, SEL setter, id value);
BOOL EeveeInterceptBackground(UIView *view, void (^sink)(UIColor *color));

BOOL ShrubSeekPlaybackSeconds(id target, double seconds);

NSDictionary *_Nullable ShrubPlaybackFacts(id state);
NSDictionary *_Nullable ShrubReadLivePlayback(id player);
BOOL ShrubSetPlaybackPaused(id player, BOOL paused);

BOOL ShrubRegisterPlaybackObserver(id player, id observer);

NS_ASSUME_NONNULL_END
