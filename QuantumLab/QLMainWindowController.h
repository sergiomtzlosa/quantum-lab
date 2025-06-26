#import <Cocoa/Cocoa.h>
#import "QLParameterFormView.h"

NS_ASSUME_NONNULL_BEGIN

@interface QLMainWindowController : NSWindowController <QLParameterFormDelegate>

- (void)runDefaultSimulation;
- (void)persistState;
- (BOOL)applyPresetNamed:(NSString *)presetName
                    mode:(QLSimulationMode)mode
                 variant:(NSInteger)variant;

- (void)solvePressed:(nullable id)sender;
- (void)togglePlayPressed:(nullable id)sender;
- (void)stepBackPressed:(nullable id)sender;
- (void)stepForwardPressed:(nullable id)sender;
- (void)resetSimulationPressed:(nullable id)sender;
- (void)set2DView:(nullable id)sender;
- (void)set3DView:(nullable id)sender;
- (void)toggleSidebar:(nullable id)sender;
- (void)resetCamera:(nullable id)sender;
- (void)exportPNG:(nullable id)sender;
- (void)exportCSV:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
