#include "clamp.h"

int	clamp_value(int value, int maximum)
{
	if (value < 0)
		return (0);
	if (value > maximum)
		return (maximum);
	return (value);
}
