#ifndef APP_H
# define APP_H

struct config
{
	int	value;
};

struct config	parse_config(int argc, char **argv);
int				render_result(const struct config *config);
int				audit_result(const struct config *config);

#endif
