#include <gem5/m5ops.h>
#include <stdio.h>
#include <stdlib.h>

#define MATRIX_SIZE 256

// Matrix multiplication workload - cache intensive
void matrix_multiply(double *A, double *B, double *C, int n)
{
	for (int i = 0; i < n; i++) {
		for (int j = 0; j < n; j++) {
			double sum = 0.0;
			for (int k = 0; k < n; k++) {
				sum += A[i * n + k] * B[k * n + j];
			}
			C[i * n + j] = sum;
		}
	}
}

int main(int argc, char *argv[])
{
	int size = MATRIX_SIZE;

	if (argc > 1) {
		size = atoi(argv[1]);
	}

	printf("Matrix multiplication: %dx%d\n", size, size);

	// Allocate matrices
	double *A = (double *)malloc(size * size * sizeof(double));
	double *B = (double *)malloc(size * size * sizeof(double));
	double *C = (double *)malloc(size * size * sizeof(double));

	if (!A || !B || !C) {
		fprintf(stderr, "Memory allocation failed\n");
		return 1;
	}

	// Initialize matrices with random values
	for (int i = 0; i < size * size; i++) {
		A[i] = (double)(i % 100) / 100.0;
		B[i] = (double)((i + 1) % 100) / 100.0;
		C[i] = 0.0;
	}

	// ======== HOT CODE ========
	puts("Setup complete. Collecting stats...");
	fflush(stdout);

	// Perform matrix multiplication
	m5_reset_stats(0, 0);
	matrix_multiply(A, B, C, size);
	m5_dump_stats(0, 0);

	puts("Stats collection complete.");
	fflush(stdout);
	// ==========================

	// Print a sample result to prevent optimization
	printf("C[0][0] = %f\n", C[0]);

	free(A);
	free(B);
	free(C);

	return 0;
}
