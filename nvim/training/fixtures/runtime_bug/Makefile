NAME := runtime_bug
CC := cc
CFLAGS := -Wall -Wextra -Werror -std=c17 -g
SRC := main.c stats.c
OBJ := $(SRC:.c=.o)

all: $(NAME)

$(NAME): $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) -o $@

%.o: %.c stats.h
	$(CC) $(CFLAGS) -c $< -o $@

test: all
	sh verify.sh

clean:
	rm -f $(OBJ)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: all test clean fclean re
