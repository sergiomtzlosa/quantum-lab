#import <Cocoa/Cocoa.h>
#import "QLParameterSet.h"
#import "QLParameterRow.h"

NS_ASSUME_NONNULL_BEGIN

@class QLParameterFormView;

@protocol QLParameterFormDelegate <NSObject>
- (void)parameterFormDidChange:(QLParameterFormView *)form key:(NSString *)key;
@end

@interface QLParameterFormView : NSView

@property (nonatomic, weak, nullable) id<QLParameterFormDelegate> delegate;
@property (nonatomic, strong, readonly) QLParameterSet *parameterSet;
@property (nonatomic, readonly) BOOL allValid;

- (void)reloadWithDefinitions:(NSArray<QLParameterDefinition *> *)definitions
                   parameters:(QLParameterSet *)parameters;
- (void)refreshVisibility;
- (void)setFormEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
