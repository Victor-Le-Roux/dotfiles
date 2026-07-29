#ifndef STATS_H
# define STATS_H

struct stats
{
	int	minimum;
	int	maximum;
	int	sum;
};

struct stats	compute_stats(int count, char **values);

#endif
