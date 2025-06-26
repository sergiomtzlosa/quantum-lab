#import "QLFFT.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

struct QLFFTPlan {
    size_t n;
    size_t *bitrev;
    double complex *twiddle;
};

static size_t QLReverseBits(size_t value, unsigned bits) {
    size_t result = 0;
    for (unsigned i = 0; i < bits; i++) {
        result = (result << 1) | (value & 1u);
        value >>= 1;
    }
    return result;
}

QLFFTPlan *QLFFTPlanCreate(size_t n) {
    if (n < 2 || (n & (n - 1)) != 0) {
        return NULL;
    }
    QLFFTPlan *plan = calloc(1, sizeof(QLFFTPlan));
    if (!plan) return NULL;
    plan->n = n;
    plan->bitrev = calloc(n, sizeof(size_t));
    plan->twiddle = calloc(n / 2, sizeof(double complex));
    if (!plan->bitrev || !plan->twiddle) {
        QLFFTPlanDestroy(plan);
        return NULL;
    }
    unsigned bits = 0;
    for (size_t v = n; v > 1; v >>= 1) bits++;
    for (size_t i = 0; i < n; i++) {
        plan->bitrev[i] = QLReverseBits(i, bits);
    }
    for (size_t i = 0; i < n / 2; i++) {
        double angle = -2.0 * M_PI * (double)i / (double)n;
        plan->twiddle[i] = cos(angle) + I * sin(angle);
    }
    return plan;
}

void QLFFTPlanDestroy(QLFFTPlan *plan) {
    if (!plan) return;
    free(plan->bitrev);
    free(plan->twiddle);
    free(plan);
}

void QLFFTExecute(QLFFTPlan *plan, double complex *data, BOOL inverse) {
    if (!plan || !data) return;
    size_t n = plan->n;
    for (size_t i = 0; i < n; i++) {
        size_t j = plan->bitrev[i];
        if (j > i) {
            double complex tmp = data[i];
            data[i] = data[j];
            data[j] = tmp;
        }
    }
    for (size_t len = 2; len <= n; len <<= 1) {
        size_t half = len >> 1;
        size_t step = n / len;
        for (size_t start = 0; start < n; start += len) {
            for (size_t j = 0; j < half; j++) {
                double complex w = plan->twiddle[j * step];
                if (inverse) w = conj(w);
                double complex u = data[start + j];
                double complex v = data[start + j + half] * w;
                data[start + j] = u + v;
                data[start + j + half] = u - v;
            }
        }
    }
    if (inverse) {
        double scale = 1.0 / (double)n;
        for (size_t i = 0; i < n; i++) {
            data[i] *= scale;
        }
    }
}

void QLFFT2DExecute(QLFFTPlan *rowPlan,
                    QLFFTPlan *colPlan,
                    double complex *data,
                    size_t nx,
                    size_t ny,
                    BOOL inverse,
                    double complex *scratch) {
    if (!rowPlan || !colPlan || !data || !scratch) return;
    if (rowPlan->n != nx || colPlan->n != ny) return;

    for (size_t y = 0; y < ny; y++) {
        QLFFTExecute(rowPlan, data + y * nx, inverse);
    }
    for (size_t x = 0; x < nx; x++) {
        for (size_t y = 0; y < ny; y++) {
            scratch[y] = data[y * nx + x];
        }
        QLFFTExecute(colPlan, scratch, inverse);
        for (size_t y = 0; y < ny; y++) {
            data[y * nx + x] = scratch[y];
        }
    }
}
