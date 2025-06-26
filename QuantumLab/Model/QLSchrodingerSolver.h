#import <Foundation/Foundation.h>
#import "QLSimulationConfig.h"
#import "QLSimulationResult.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^QLProgressCallback)(double fraction);

@interface QLSchrodingerSolver : NSObject

+ (nullable QLSimulationResult *)solveConfig:(QLSimulationConfig *)config
                                    progress:(nullable QLProgressCallback)progress
                                       error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
