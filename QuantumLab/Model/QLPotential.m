#import "QLPotential.h"
#include <math.h>

double QLPotentialValue(QLPotentialType type,
                        double x,
                        double y,
                        QLSimulationConfig *config,
                        BOOL is2D) {
    switch (type) {
        case QLPotentialTypeFree:
            return 0.0;

        case QLPotentialTypeHarmonic: {
            double r2 = is2D ? (x * x + y * y) : (x * x);
            return 0.5 * config.mass * config.omega * config.omega * r2;
        }

        case QLPotentialTypeBarrier: {
            return (fabs(x - config.barrierX) <= config.barrierWidth * 0.5) ? config.v0 : 0.0;
        }

        case QLPotentialTypeDoubleBarrier: {
            double d = config.barrierSeparation * 0.5;
            double w = config.barrierWidth * 0.5;
            return ((fabs(x - d) <= w) || (fabs(x + d) <= w)) ? config.v0 : 0.0;
        }

        case QLPotentialTypeLinear:
            return -config.field * x;

        case QLPotentialTypeLattice: {
            double a = config.latticePeriod;
            if (a <= 0) return 0.0;
            if (is2D) {
                return config.v0 * (cos(2.0 * M_PI * x / a) + cos(2.0 * M_PI * y / a));
            }
            return config.v0 * cos(2.0 * M_PI * x / a);
        }

        case QLPotentialTypeDoubleSlit: {
            BOOL inWall = fabs(x - config.barrierX) <= config.wallThickness * 0.5;
            if (!inWall) return 0.0;
            double slitY = config.slitSeparation * 0.5;
            BOOL inSlit = (fabs(y - slitY) <= config.slitWidth * 0.5) ||
                          (fabs(y + slitY) <= config.slitWidth * 0.5);
            return inSlit ? 0.0 : config.v0;
        }

        case QLPotentialTypeCircularWell: {
            double r2 = x * x + y * y;
            return (r2 <= config.wellRadius * config.wellRadius) ? -config.v0 : 0.0;
        }
    }
    return 0.0;
}
