#include "clamp.h"
#include <stdio.h>

int	print_clamped_value(int value, int maximum)
{
	printf("%d\n", clamp_value(value, maximum));
	return (0);
}
