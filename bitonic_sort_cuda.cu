#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

// CUDA kernel for bitonic sort step
__global__ void bitonicSortStep(int *data, int j, int k, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int ixj = i ^ j;
    
    if (i >= n || ixj >= n) return;
    
    if (ixj > i) {
        if ((i & k) == 0) {
            if (data[i] > data[ixj]) {
                int temp = data[i];
                data[i] = data[ixj];
                data[ixj] = temp;
            }
        } else {
            if (data[i] < data[ixj]) {
                int temp = data[i];
                data[i] = data[ixj];
                data[ixj] = temp;
            }
        }
    }
}

__global__ void bitonicSort(int *data, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    
    for (int k = 2; k <= n; k <<= 1) {
        for (int j = k >> 1; j > 0; j >>= 1) {
            __syncthreads();
            int ixj = i ^ j;
            if (ixj > i) {
                if ((i & k) == 0) {
                    if (data[i] > data[ixj]) {
                        int temp = data[i];
                        data[i] = data[ixj];
                        data[ixj] = temp;
                    }
                } else {
                    if (data[i] < data[ixj]) {
                        int temp = data[i];
                        data[i] = data[ixj];
                        data[ixj] = temp;
                    }
                }
            }
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <depth>\n", argv[0]);
        return 1;
    }
    
    int depth = atoi(argv[1]);
    if (depth < 0 || depth > 30) {
        fprintf(stderr, "Depth must be between 0 and 30\n");
        return 1;
    }
    
    int n = 1 << depth;  // 2^depth elements
    size_t size = n * sizeof(int);
    
    int *h_data = (int *)malloc(size);
    if (h_data == NULL) {
        fprintf(stderr, "Failed to allocate host memory\n");
        return 1;
    }
    
    // Initialize array in reverse order (similar to Bend's gen function)
    // Generate values from 2^depth down to 0
    for (int i = 0; i < n; i++) {
        h_data[i] = n - 1 - i;
    }
    
    // Allocate device memory
    int *d_data;
    cudaError_t err = cudaMalloc((void **)&d_data, size);
    if (err != cudaSuccess) {
        fprintf(stderr, "Failed to allocate device memory: %s\n", cudaGetErrorString(err));
        free(h_data);
        return 1;
    }
    
    err = cudaMemcpy(d_data, h_data, size, cudaMemcpyHostToDevice);
    if (err != cudaSuccess) {
        fprintf(stderr, "Failed to copy data to device: %s\n", cudaGetErrorString(err));
        cudaFree(d_data);
        free(h_data);
        return 1;
    }
    
    // Setup CUDA events for timing
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    int threadsPerBlock = 256;
    int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;
    
    cudaEventRecord(start);
    
    for (int k = 2; k <= n; k <<= 1) {
        for (int j = k >> 1; j > 0; j >>= 1) {
            bitonicSortStep<<<blocksPerGrid, threadsPerBlock>>>(d_data, j, k, n);
            cudaDeviceSynchronize();
            err = cudaGetLastError();
            if (err != cudaSuccess) {
                fprintf(stderr, "Kernel launch failed: %s\n", cudaGetErrorString(err));
                cudaEventDestroy(start);
                cudaEventDestroy(stop);
                cudaFree(d_data);
                free(h_data);
                return 1;
            }
        }
    }
    
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    
    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    float seconds = milliseconds / 1000.0f;
    
    printf("TIME: %.6f\n", seconds);
    
    
    
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_data);
    free(h_data);
    
    return 0;
}

