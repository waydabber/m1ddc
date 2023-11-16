# -- VARIABLES

# Project name
NAME =		m1ddc

# Compiler
CC =		clang
CFLAGS =	-Wall -Werror -Wextra -fmodules
CPPFLAGS =	-I $(INC_DIR)
DEPFLAGS =	-MMD

# Commands
RM =		rm -f
RMDIR =		rm -rf
MKDIR =		mkdir -p
MAKE =		make -C

# Paths
INC_DIR =	includes

SRC_DIR =	sources
SOURCES =	i2c \
			m1ddc \
			utils \

OBJ_DIR =	.objects
OBJECTS = 	$(patsubst %,$(OBJ_DIR)/%,$(SOURCES:=.o))


# -- IMPLICIT RULES / LINKING

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.m Makefile
	@$(CC) -c $< -o $@ $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS)

# -- RULES

all: $(NAME)

$(NAME): $(OBJ_DIR) $(OBJECTS)
	@$(CC) $(OBJECTS) -o $(NAME)
	@printf "Created binary \"$(NAME)\"\n"

$(OBJ_DIR):
	@$(MKDIR) $(OBJ_DIR)

clean:
	@if [ -e $(OBJ_DIR) ]; \
	then \
		$(RMDIR) $(OBJ_DIR); \
		printf "Objects deleted\n"; \
	fi;

fclean: clean
	@if [ -e $(NAME) ]; \
	then \
		$(RM) $(NAME); \
		printf "Binary deleted\n"; \
	fi;

re: fclean all

.PHONY: all clean fclean re

-include $(OBJECTS:.o=.d)

