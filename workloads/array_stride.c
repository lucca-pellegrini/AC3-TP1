#include <stdio.h>
#include <stdlib.h>

#define ARRAY_SIZE (16 * 1024 * 1024) // 16MB array
#define ITERATIONS 10

// Array stride access pattern - tests cache line utilization
void stride_access(int *array, int size, int stride)
{
	long sum = 0;
	for (int iter = 0; iter < ITERATIONS; iter++) {
		for (int i = 0; i < size; i += stride) {
			sum += array[i];
		}
	}
	// Prevent optimization
	printf("Sum: %ld\n", sum);
}

int main(int argc, char *argv[])
{
	int stride = 1;

	if (argc > 1) {
		stride = atoi(argv[1]);
	}

	printf("Array stride access test\n");
	printf("Array size: %d integers (%ld MB)\n", ARRAY_SIZE,
	       (long)ARRAY_SIZE * sizeof(int) / (1024 * 1024));
	printf("Stride: %d\n", stride);

	// Allocate array
	int *array = (int *)malloc(ARRAY_SIZE * sizeof(int));
	if (!array) {
		fprintf(stderr, "Memory allocation failed\n");
		return 1;
	}

	// Initialize array
	for (int i = 0; i < ARRAY_SIZE; i++) {
		array[i] = i % 1000;
	}

	// Perform stride access
	stride_access(array, ARRAY_SIZE, stride);

	free(array);
	return 0;
}
