/*
 * SPDX-License-Identifier: ISC
 * SPDX-FileCopyrightText: Copyright © 2026 Lucca M. A. Pellegrini <lucca@verticordia.com>
 */

#include <gem5/m5ops.h>
#include <stdio.h>
#include <stdlib.h>

#define ARRAY_SIZE (8 * 1024 * 1024) // 8M integers
#define NUM_ACCESSES (10 * 1024 * 1024)

// Random access pattern - worst case for cache
void random_access(int *array, int size, int num_accesses)
{
	long sum = 0;
	unsigned int seed = 42;

	for (int i = 0; i < num_accesses; i++) {
		int index = rand_r(&seed) % size;
		sum += array[index];
		array[index] = sum % 1000;
	}

	// Prevent optimization
	printf("Final sum: %ld\n", sum);
}

int main(int argc, char *argv[])
{
	int num_accesses = NUM_ACCESSES;

	if (argc > 1) {
		num_accesses = atoi(argv[1]);
	}

	printf("Random access pattern test\n");
	printf("Array size: %d integers (%ld MB)\n", ARRAY_SIZE,
	       (long)ARRAY_SIZE * sizeof(int) / (1024 * 1024));
	printf("Number of accesses: %d\n", num_accesses);

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

	// ======== HOT CODE ========
	puts("Setup complete. Collecting stats...");
	fflush(stdout);

	// Perform random access
	m5_reset_stats(0, 0);
	random_access(array, ARRAY_SIZE, num_accesses);
	m5_dump_stats(0, 0);

	puts("Stats collection complete.");
	fflush(stdout);
	// ==========================

	free(array);
	return 0;
}
