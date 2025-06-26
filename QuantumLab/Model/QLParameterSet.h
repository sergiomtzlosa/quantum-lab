#import <Foundation/Foundation.h>
#import "QLParameterDefinition.h"

NS_ASSUME_NONNULL_BEGIN

@interface QLParameterSet : NSObject

@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *values;

- (instancetype)init;
- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary;

- (void)setValue:(nullable id)value forKey:(NSString *)key;
- (nullable id)valueForKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

- (void)applyDefaults:(NSArray<QLParameterDefinition *> *)definitions;
- (QLParameterSet *)copyWithZone:(nullable NSZone *)zone;

@end

NS_ASSUME_NONNULL_END
