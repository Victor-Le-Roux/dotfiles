#include "app.h"

int	main(int argc, char **argv)
{
	struct config	config;

	config = parse_config(argc, argv);
	if (render_result(config) != 0)
		return (1);
	return (audit_result(&config));
}
