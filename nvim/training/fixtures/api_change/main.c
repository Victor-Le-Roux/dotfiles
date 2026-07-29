#include "clamp.h"
#include <stdlib.h>

int	main(int argc, char **argv)
{
	if (argc != 3)
		return (1);
	return (print_clamped_value(atoi(argv[1]), atoi(argv[2])));
}
