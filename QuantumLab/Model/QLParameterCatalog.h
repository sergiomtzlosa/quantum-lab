#import <Foundation/Foundation.h>
#import "QLParameterDefinition.h"
#import "QLParameterSet.h"

NS_ASSUME_NONNULL_BEGIN

@interface QLParameterCatalog : NSObject

+ (NSArray<QLParameterDefinition *> *)definitionsForMode:(QLSimulationMode)mode
                                                 variant:(NSInteger)variant;

+ (QLParameterSet *)defaultParametersForMode:(QLSimulationMode)mode
                                     variant:(NSInteger)variant;

+ (NSArray<NSString *> *)presetNamesForMode:(QLSimulationMode)mode
                                    variant:(NSInteger)variant;

+ (QLParameterSet *)presetParametersForMode:(QLSimulationMode)mode
                                    variant:(NSInteger)variant
                                      index:(NSInteger)index;

+ (NSString *)potentialNameForType:(QLPotentialType)type;

@end

NS_ASSUME_NONNULL_END
