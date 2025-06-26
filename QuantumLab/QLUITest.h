#import <Cocoa/Cocoa.h>

@class QLMainWindowController;

NS_ASSUME_NONNULL_BEGIN

/// Debug-only UI smoke test. Exercises the window controls, solvers, plot views,
/// options, playback, exports, persistence, and appearance switching without
/// opening save panels or other modal UI.
@interface QLUITest : NSObject

+ (void)runWithWindowController:(QLMainWindowController *)controller
    completion:(void (^)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END
