#include "app.h"
#include <stdlib.h>

struct config	parse_config(int argc, char **argv)
{
	struct config	result;

	result.value = 0;
	if (argc == 2)
		result.value = parse_number(argv[1]);
	result.maximum = result.value;
	return (result);
}
