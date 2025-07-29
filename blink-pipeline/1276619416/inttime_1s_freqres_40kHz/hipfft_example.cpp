#include <stdio.h>
#include <stdlib.h>
#include <hipfft/hipfft.h>
#include <assert.h>

/********************/
/* CUDA ERROR CHECK */
/********************/
#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(hipError_t code, char *file, int line, bool abort=true)
{
    if (code != hipSuccess) 
    {
        fprintf(stderr,"GPUassert: %s %s %d\n", hipGetErrorString(code), file, line);
        if (abort) { getchar(); exit(code); }
    }
}

/*********************/
/* CUFFT ERROR CHECK */
/*********************/
static const char *_cudaGetErrorEnum(hipfftResult error)
{
    switch (error)
    {
        case HIPFFT_SUCCESS:
            return "HIPFFT_SUCCESS";

        case HIPFFT_INVALID_PLAN:
            return "HIPFFT_INVALID_PLAN";

        case HIPFFT_ALLOC_FAILED:
            return "HIPFFT_ALLOC_FAILED";

        case HIPFFT_INVALID_TYPE:
            return "HIPFFT_INVALID_TYPE";

        case HIPFFT_INVALID_VALUE:
            return "HIPFFT_INVALID_VALUE";

        case HIPFFT_INTERNAL_ERROR:
            return "HIPFFT_INTERNAL_ERROR";

        case HIPFFT_EXEC_FAILED:
            return "HIPFFT_EXEC_FAILED";

        case HIPFFT_SETUP_FAILED:
            return "HIPFFT_SETUP_FAILED";

        case HIPFFT_INVALID_SIZE:
            return "HIPFFT_INVALID_SIZE";

        case HIPFFT_UNALIGNED_DATA:
            return "HIPFFT_UNALIGNED_DATA";
    }

    return "<unknown>";
}

#define cufftSafeCall(err)      __cufftSafeCall(err, __FILE__, __LINE__)
inline void __cufftSafeCall(hipfftResult err, const char *file, const int line)
{
    if( HIPFFT_SUCCESS != err) {
                fprintf(stderr, "CUFFT error in file '%s', line %d\n %s\nerror %d: %s\nterminating!\n",__FILE__, __LINE__,err, \
                           _cudaGetErrorEnum(err)); \
             hipDeviceReset(); assert(0); \
    }
}

/********/
/* MAIN */
/********/
int main() {

    hipfftHandle forward_plan, inverse_plan; 

    int batch = 1;
    int rank = 2;

    int nRows = 5;
    int nCols = 5;
    int n[2] = {nRows, nCols};

    int idist = nRows*nCols;
    int odist = nRows*(nCols/2+1);

    int inembed[] = {nRows, nCols};
    int onembed[] = {nRows, nCols/2+1};

    int istride = 1;
    int ostride = 1;

    cufftSafeCall(hipfftPlanMany(&forward_plan,  rank, n, inembed, istride, idist, onembed, ostride, odist, HIPFFT_R2C, batch));

    float *h_in = (float*)malloc(sizeof(float)*nRows*nCols*batch);
    for(int i=0; i<nRows*nCols*batch; i++) h_in[i] = 1.f;

    float2* h_freq = (float2*)malloc(sizeof(float2)*nRows*(nCols/2+1)*batch);

    float* d_in;            
    gpuErrchk(hipMalloc(&d_in, sizeof(float)*nRows*nCols*batch)); 

    float2* d_freq; 
    gpuErrchk(hipMalloc(&d_freq, sizeof(float2)*nRows*(nCols/2+1)*batch)); 

    gpuErrchk(hipMemcpy(d_in,h_in,sizeof(float)*nRows*nCols*batch,hipMemcpyHostToDevice));

    cufftSafeCall(hipfftExecR2C(forward_plan, d_in, d_freq));

    gpuErrchk(hipMemcpy(h_freq,d_freq,sizeof(float2)*nRows*(nCols/2+1)*batch,hipMemcpyDeviceToHost));

    for(int i=0; i<nRows*(nCols/2+1)*batch; i++) printf("Direct transform: %i %f %f\n",i,h_freq[i].x,h_freq[i].y); 

    cufftSafeCall(hipfftPlanMany(&inverse_plan, rank, n, onembed, ostride, odist, inembed, istride, idist, HIPFFT_C2R, batch));

    cufftSafeCall(hipfftExecC2R(inverse_plan, d_freq, d_in));

    gpuErrchk(hipMemcpy(h_in,d_in,sizeof(float)*nRows*nCols*batch,hipMemcpyDeviceToHost));

    for(int i=0; i<nRows*nCols*batch; i++) printf("Inverse transform: %i %f \n",i,h_in[i]); 

 return 0;
}
