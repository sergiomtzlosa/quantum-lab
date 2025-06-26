#import <Cocoa/Cocoa.h>
#import "QLParameterDefinition.h"

NS_ASSUME_NONNULL_BEGIN

@interface QLParameterRow : NSView <NSTextFieldDelegate>

@property (nonatomic, strong) QLParameterDefinition *definition;
@property (nonatomic, copy, nullable) void (^onChange)(void);
@property (nonatomic, readonly) BOOL isValid;

- (instancetype)initWithDefinition:(QLParameterDefinition *)definition;
- (void)setParameterValue:(nullable id)value;
- (nullable id)parameterValue;
- (BOOL)isVisibleForValues:(NSDictionary<NSString *, id> *)values;
- (void)updateVisibilityForValues:(NSDictionary<NSString *, id> *)values;

@end

NS_ASSUME_NONNULL_END
