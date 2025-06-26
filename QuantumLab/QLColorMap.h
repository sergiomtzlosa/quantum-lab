#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface QLColorMap : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSArray<NSColor *> *stops;

+ (NSArray<NSString *> *)colorMapNames;
+ (instancetype)colorMapNamed:(NSString *)name;
+ (instancetype)defaultMap;

- (NSColor *)colorAtIndex:(NSInteger)index;
- (NSColor *)colorAtUnit:(double)unit;
- (NSImage *)gradientImage;
- (NSGradient *)gradient;

@end

NS_ASSUME_NONNULL_END
