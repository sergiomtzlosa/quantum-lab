#import <Foundation/Foundation.h>
#import "QLSimulationConfig.h"
#import "QLSimulationResult.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^QLHeisenbergProgressCallback)(double fraction);

@interface QLHeisenbergSolver : NSObject

+ (nullable QLSimulationResult *)solveConfig:(QLSimulationConfig *)config
                                    progress:(nullable QLHeisenbergProgressCallback)progress
                                       error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
