#include "stats.h"
#include <stdlib.h>

struct stats	compute_stats(int count, char **values)
{
	struct stats	result;
	int				index;
	int				value;

	result.minimum = atoi(values[0]);
	result.maximum = 0;
	result.sum = 0;
	index = 0;
	while (index < count)
	{
		value = atoi(values[index]);
		if (value < result.minimum)
			result.minimum = value;
		if (value > result.maximum)
			result.maximum = value;
		result.sum += value;
		index++;
	}
	return (result);
}
