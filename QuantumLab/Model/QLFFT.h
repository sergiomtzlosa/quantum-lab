#import <Foundation/Foundation.h>
#include <complex.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct QLFFTPlan QLFFTPlan;

QLFFTPlan *_Nullable QLFFTPlanCreate(size_t n);
void QLFFTPlanDestroy(QLFFTPlan *_Nullable plan);
void QLFFTExecute(QLFFTPlan *plan, double complex *data, BOOL inverse);

// Row then column transform. scratch must hold at least ny elements.
void QLFFT2DExecute(QLFFTPlan *rowPlan,
                    QLFFTPlan *colPlan,
                    double complex *data,
                    size_t nx,
                    size_t ny,
                    BOOL inverse,
                    double complex *scratch);

NS_ASSUME_NONNULL_END
