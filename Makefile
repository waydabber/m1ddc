NAME = m1ddc

all:
	@clang -fmodules -o $(NAME) m1ddc.m
	@echo "Created binary \"$(NAME)\""

clean:
	@rm -f $(NAME)
	@echo "Deleted binary \"$(NAME)\""

re: clean all

.PHONY: all clean re
