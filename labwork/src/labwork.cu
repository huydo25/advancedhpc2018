#include <stdio.h>
#include <include/labwork.h>
#include <cuda_runtime_api.h>
#include <omp.h>

#define ACTIVE_THREADS 4

int main(int argc, char **argv) {
    printf("USTH ICT Master 2018, Advanced Programming for HPC.\n");
    if (argc < 2) {
        printf("Usage: labwork <lwNum> <inputImage>\n");
        printf("   lwNum        labwork number\n");
        printf("   inputImage   the input file name, in JPEG format\n");
        return 0;
    }

    int lwNum = atoi(argv[1]);
    std::string inputFilename;

    // pre-initialize CUDA to avoid incorrect profiling
    printf("Warming up...\n");
    char *temp;
    cudaMalloc(&temp, 1024);

    Labwork labwork;
    if (lwNum != 2 ) {
        inputFilename = std::string(argv[2]);
        labwork.loadInputImage(inputFilename);
    }

    printf("Starting labwork %d\n", lwNum);
    Timer timer;
//    timer.start();
    switch (lwNum) {
        case 1:
            timer.start();
            labwork.labwork1_CPU();
            printf("labwork 1 CPU ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
            labwork.saveOutputImage("labwork1-cpu-out.jpg");
            timer.start();
            labwork.labwork1_OpenMP();
            printf("labwork 1 OpenMP ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
            labwork.saveOutputImage("labwork1-openmp-out.jpg");
            break;
        case 2:
            labwork.labwork2_GPU();
            break;
        case 3:
            timer.start();
            labwork.labwork3_GPU();
            labwork.saveOutputImage("labwork3-gpu-out.jpg");
            printf("labwork 3 CPU ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
            break;
        case 4:
            timer.start();
            labwork.labwork4_GPU();
            labwork.saveOutputImage("labwork4-gpu-out.jpg");
            printf("labwork 4 CPU ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
            break;
        case 5:
            timer.start();
            labwork.labwork5_CPU();
            printf("labwork 5 CPU ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
            labwork.saveOutputImage("labwork5-cpu-out.jpg");
            timer.start();
            labwork.labwork5_GPU();
            printf("labwork 5 global memory GPU ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
            labwork.saveOutputImage("labwork5-global-memory-gpu-out.jpg");
            timer.start();
            labwork.labwork5_GPU_on_shared_memory();
            printf("labwork 5 shared memory GPU ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
            labwork.saveOutputImage("labwork5-shared-memory-gpu-out.jpg");
            break;
        case 6:
            labwork.labwork6_GPU();
            labwork.saveOutputImage("labwork6-gpu-out.jpg");
            break;
        case 7:
            labwork.labwork7_GPU();
            labwork.saveOutputImage("labwork7-gpu-out.jpg");
            break;
        case 8:
            labwork.labwork8_GPU();
            labwork.saveOutputImage("labwork8-gpu-out.jpg");
            break;
        case 9:
            labwork.labwork9_GPU();
            labwork.saveOutputImage("labwork9-gpu-out.jpg");
            break;
        case 10:
            labwork.labwork10_GPU();
            labwork.saveOutputImage("labwork10-gpu-out.jpg");
            break;
    }
//    printf("labwork %d ellapsed %.1fms\n", lwNum, timer.getElapsedTimeInMilliSec());
}

void Labwork::loadInputImage(std::string inputFileName) {
    inputImage = jpegLoader.load(inputFileName);
}

void Labwork::saveOutputImage(std::string outputFileName) {
    jpegLoader.save(outputFileName, outputImage, inputImage->width, inputImage->height, 90);
}

void Labwork::labwork1_CPU() {
    int pixelCount = inputImage->width * inputImage->height;
    outputImage = static_cast<char *>(malloc(pixelCount * 3));
    for (int j = 0; j < 100; j++) {		// let's do it 100 times, otherwise it's too fast!
        for (int i = 0; i < pixelCount; i++) {
            outputImage[i * 3] = (char) (((int) inputImage->buffer[i * 3] + (int) inputImage->buffer[i * 3 + 1] +
                                          (int) inputImage->buffer[i * 3 + 2]) / 3);
            outputImage[i * 3 + 1] = outputImage[i * 3];
            outputImage[i * 3 + 2] = outputImage[i * 3];
        }
    }
}

void Labwork::labwork1_OpenMP() {
    int pixelCount = inputImage->width * inputImage->height;
    outputImage = static_cast<char *>(malloc(pixelCount * 3));
    // #pragma omp parallel for 
    #pragma omp target teams num_teams(4)
    {
    for (int j = 0; j < 100; j++) {		// let's do it 100 times, otherwise it's too fast!
        for (int i = 0; i < pixelCount; i++) {
            outputImage[i * 3] = (char) (((int) inputImage->buffer[i * 3] + (int) inputImage->buffer[i * 3 + 1] +
                                          (int) inputImage->buffer[i * 3 + 2]) / 3);
            outputImage[i * 3 + 1] = outputImage[i * 3];
            outputImage[i * 3 + 2] = outputImage[i * 3];
        }
    }
    }
}

int getSPcores(cudaDeviceProp devProp) {
    int cores = 0;
    int mp = devProp.multiProcessorCount;
    switch (devProp.major) {
        case 2: // Fermi
            if (devProp.minor == 1) cores = mp * 48;
            else cores = mp * 32;
            break;
        case 3: // Kepler
            cores = mp * 192;
            break;
        case 5: // Maxwell
            cores = mp * 128;
            break;
        case 6: // Pascal
            if (devProp.minor == 1) cores = mp * 128;
            else if (devProp.minor == 0) cores = mp * 64;
            else printf("Unknown device type\n");
            break;
        default:
            printf("Unknown device type\n");
            break;
    }
    return cores;
}

void Labwork::labwork2_GPU() {

    int numDevices = 0;
    cudaGetDeviceCount(&numDevices);
    printf("Number of GPU: ", numDevices);
    for(int i=0; i< numDevices; i++){
        cudaDeviceProp p ;
        cudaGetDeviceProperties(&p, i);
        printf("Device: #%d \n", i);
        printf("GPU name: %s\n", p.name);
        printf("Clock Rate:%d\n", p.clockRate);
        printf("Multi Processor %d\n", p.multiProcessorCount);
        printf("Cores :%d\n", getSPcores(p));
        printf("Wrap Size:%d\n\n", p.warpSize);
        printf("Memory ClockRate: %d\n", p.memoryClockRate);
        printf("Memory Bus Width: %d\n", p.memoryBusWidth);
        printf("Memory Band Width: %d\n\n", p.memoryClockRate*p.memoryBusWidth);
        //printf("%d \n", p.maxThreadsPerBlock);
        //printf("%d %d %d  \n", p.maxThreadsDim[0], p.maxThreadsDim[1],  p.maxThreadsDim[2]);
        //printf("%d %d %d \n", p.maxGridSize[0],p.maxGridSize[1], p.maxGridSize[2] );
    }
    
}

__global__ void grayscale(uchar3 *input, uchar3 *output) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    unsigned char g = (input[tid].x + input[tid].y + input[tid].z) / 3;
    output[tid].z = output[tid].y = output[tid].x = g;
}

void Labwork::labwork3_GPU() {
    int pixelCount = inputImage->width * inputImage->height;
    outputImage = static_cast<char *>(malloc(pixelCount * 3));
    int blockSize = 1024;
    int numBlock = pixelCount / blockSize;
    
    //printf("pixelCount %d blockSize %d numBlock %d\n", pixelCount, blockSize, numBlock);
    uchar3 *devInput; 
    uchar3 *devGray; 
    
    cudaMalloc(&devInput, pixelCount * sizeof(uchar3));
    cudaMalloc(&devGray, pixelCount * sizeof(uchar3));
    cudaMemcpy(devInput, inputImage->buffer , pixelCount * sizeof(uchar3), cudaMemcpyHostToDevice);  
    grayscale<<<numBlock, blockSize>>>(devInput,devGray);
    cudaMemcpy(outputImage, devGray, pixelCount * sizeof(uchar3),cudaMemcpyDeviceToHost);
    cudaFree(devInput);
    cudaFree(devGray);
       
}

__global__ void grayscale2D(uchar3 *input, uchar3 *output) {
    int tidx = threadIdx.x + blockIdx.x * blockDim.x;
    int tidy = threadIdx.y + blockIdx.y * blockDim.y;
    int tid = tidx + tidy * gridDim.x * blockDim.x;
    unsigned char g = (input[tid].x + input[tid].y + input[tid].z) / 3;
    output[tid].z = output[tid].y = output[tid].x = g;
}


void Labwork::labwork4_GPU() {
    int pixelCount = inputImage->width * inputImage->height;
    outputImage = static_cast<char *>(malloc(pixelCount * 3));
    dim3 blockSize = dim3(32, 32);
    dim3 gridSize = dim3(inputImage->width/ 32 +1, inputImage->height/ 32 +1 );
    //printf("pixelCount %d blockSize %d gridSize x %d and y %d\n", pixelCount, blockSize, gridSize.x, gridSize.y);
    
   
    uchar3 *devInput; 
    uchar3 *devGray; 
    
    cudaMalloc(&devInput, pixelCount * sizeof(uchar3));
    cudaMalloc(&devGray, pixelCount * sizeof(uchar3));
    cudaMemcpy(devInput, inputImage->buffer , pixelCount * sizeof(uchar3), cudaMemcpyHostToDevice);  
    grayscale2D<<<gridSize, blockSize>>>(devInput,devGray);
    cudaMemcpy(outputImage, devGray, pixelCount * sizeof(uchar3),cudaMemcpyDeviceToHost);
    cudaFree(devInput);
    cudaFree(devGray);
}

// CPU implementation of Gaussian Blur
void Labwork::labwork5_CPU() {
    int kernel[] = { 0, 0, 1, 2, 1, 0, 0,  
                     0, 3, 13, 22, 13, 3, 0,  
                     1, 13, 59, 97, 59, 13, 1,  
                     2, 22, 97, 159, 97, 22, 2,  
                     1, 13, 59, 97, 59, 13, 1,  
                     0, 3, 13, 22, 13, 3, 0,
                     0, 0, 1, 2, 1, 0, 0 };
    int pixelCount = inputImage->width * inputImage->height;
    outputImage = (char*) malloc(pixelCount * sizeof(char) * 3);
    for (int row = 0; row < inputImage->height; row++) {
        for (int col = 0; col < inputImage->width; col++) {
            int sum = 0;
            int c = 0;
            for (int y = -3; y <= 3; y++) {
                for (int x = -3; x <= 3; x++) {
                    int i = col + x;
                    int j = row + y;
                    if (i < 0) continue;
                    if (i >= inputImage->width) continue;
                    if (j < 0) continue;
                    if (j >= inputImage->height) continue;
                    int tid = j * inputImage->width + i;
                    unsigned char gray = (inputImage->buffer[tid * 3] + inputImage->buffer[tid * 3 + 1] + inputImage->buffer[tid * 3 + 2])/3;
                    int coefficient = kernel[(y+3) * 7 + x + 3];
                    sum = sum + gray * coefficient;
                    c += coefficient;
                }
            }
            sum /= c;
            int posOut = row * inputImage->width + col;
            outputImage[posOut * 3] = outputImage[posOut * 3 + 1] = outputImage[posOut * 3 + 2] = sum;
        }
    }
}

__global__ void blurImage(uchar3 *input, uchar3 *output, int width, int height) {
    int tidx = threadIdx.x + blockIdx.x * blockDim.x;
    int tidy = threadIdx.y + blockIdx.y * blockDim.y;
    int tid = tidx + tidy * width;
    
    int kernel[] = { 0, 0, 1, 2, 1, 0, 0,  
                     0, 3, 13, 22, 13, 3, 0,  
                     1, 13, 59, 97, 59, 13, 1,  
                     2, 22, 97, 159, 97, 22, 2,  
                     1, 13, 59, 97, 59, 13, 1,  
                     0, 3, 13, 22, 13, 3, 0,
                     0, 0, 1, 2, 1, 0, 0 };
    int sum = 0;
    int c = 0;
    for (int y = -3; y <= 3; y++) {
        for (int x = -3; x <= 3; x++) {
            int i = tidx + x;
            int j = tidy + y;
            if (i < 0) continue;
            if (i >= width) continue;
            if (j < 0) continue;
            if (j >= height) continue;
            unsigned char gray = (input[tid].x + input[tid].y + input[tid].z) / 3;
            int coefficient = kernel[(y+3) * 7 + x + 3];
            sum = sum + gray * coefficient;
            c += coefficient;
        }
    }
    sum /= c;
    output[tid].z = output[tid].y = output[tid].x = sum;
}

void Labwork::labwork5_GPU() {

    int pixelCount = inputImage->width * inputImage->height;
    outputImage = static_cast<char *>(malloc(pixelCount * 3));
    dim3 blockSize = dim3(32, 32);
    dim3 gridSize = dim3((inputImage->width+blockSize.x -1)/ blockSize.x, (inputImage->height + blockSize.y -1)/ blockSize.y );
    
    uchar3 *devInput; 
    uchar3 *devGray; 

    cudaMalloc(&devInput, pixelCount * sizeof(uchar3));
    cudaMalloc(&devGray, pixelCount * sizeof(uchar3));
    
    cudaMemcpy(devInput, inputImage->buffer, pixelCount * sizeof(uchar3), cudaMemcpyHostToDevice);
    for(int i=0; i<100; i++){
        blurImage<<<gridSize, blockSize>>>(devInput, devGray, inputImage->width, inputImage->height);
    }
    cudaMemcpy(outputImage, devGray, pixelCount * sizeof(uchar3), cudaMemcpyDeviceToHost);
    
    cudaFree(devInput);
    cudaFree(devGray);
    
}
__global__ void blurImageOnSharedMemory(uchar3 *input, uchar3 *output, int width, int height, int *weight) {
    
    int tidx = threadIdx.x + blockIdx.x * blockDim.x;
    int tidy = threadIdx.y + blockIdx.y * blockDim.y;
    int localtid = threadIdx.x + threadIdx.y * blockDim.x;
    __shared__ int shared_weight[49]; 
    if (localtid < 49)
        shared_weight[localtid] = weight[localtid];
    __syncthreads();    

    int sum = 0;
    int c = 0;
    for (int y = -3; y <= 3; y++) {
        for (int x = -3; x <= 3; x++) {
            int i = tidx + x;
            int j = tidy + y;
            if (i < 0) continue;
            if (i >= width) continue;
            if (j < 0) continue;
            if (j >= height) continue;
            int tid = width * j + i; // RowSize * j + i, get the position of our pixel
            unsigned char gray = (input[tid].x + input[tid].y + input[tid].z) / 3;
            int coefficient = shared_weight[(y+3) * 7 + x + 3];
            sum = sum + gray * coefficient;
            c += coefficient;
        }
    }
    sum /= c;
    int globaltid = tidx + tidy * width;
    output[globaltid].y = output[globaltid].x = output[globaltid].z = sum;
    
}

void Labwork::labwork5_GPU_on_shared_memory() {

    int pixelCount = inputImage->width * inputImage->height;
    outputImage = static_cast<char *>(malloc(pixelCount * 3));
    dim3 blockSize = dim3(16, 16);
    dim3 gridSize = dim3((inputImage->width+blockSize.x -1)/ blockSize.x, (inputImage->height + blockSize.y -1)/ blockSize.y );
    
    uchar3 *devInput; 
    uchar3 *devGray; 
    int *devWeight;
    int kernel[] = { 0, 0, 1, 2, 1, 0, 0,  
                     0, 3, 13, 22, 13, 3, 0,  
                     1, 13, 59, 97, 59, 13, 1,  
                     2, 22, 97, 159, 97, 22, 2,  
                     1, 13, 59, 97, 59, 13, 1,  
                     0, 3, 13, 22, 13, 3, 0,
                     0, 0, 1, 2, 1, 0, 0 };
                     
    cudaMalloc(&devInput, pixelCount * sizeof(uchar3));
    cudaMalloc(&devGray, pixelCount * sizeof(uchar3));
    cudaMalloc(&devWeight, sizeof(kernel));
    
    cudaMemcpy(devInput, inputImage->buffer, pixelCount * sizeof(uchar3), cudaMemcpyHostToDevice);
    cudaMemcpy(devWeight, kernel, 49* sizeof(int),cudaMemcpyHostToDevice);
    for(int i=0; i<100; i++){
        blurImageOnSharedMemory<<<gridSize, blockSize>>>(devInput, devGray, inputImage->width, inputImage->height, devWeight);
    }
    cudaMemcpy(outputImage, devGray, pixelCount * sizeof(uchar3), cudaMemcpyDeviceToHost);
    
    cudaFree(devInput);
    cudaFree(devGray);
    cudaFree(devWeight);
}

void Labwork::labwork6_GPU() {

}

void Labwork::labwork7_GPU() {

}

void Labwork::labwork8_GPU() {

}

void Labwork::labwork9_GPU() {

}

void Labwork::labwork10_GPU() {

}
