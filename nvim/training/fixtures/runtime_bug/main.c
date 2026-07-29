#include "stats.h"
#include <stdio.h>

int	main(int argc, char **argv)
{
	struct stats	result;

	if (argc < 2)
		return (1);
	result = compute_stats(argc - 1, argv + 1);
	printf("min=%d max=%d sum=%d\n",
		result.minimum, result.maximum, result.sum);
	return (0);
}
