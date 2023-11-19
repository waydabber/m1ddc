# -- VARIABLES

# Project name
NAME =		m1ddc

# Compiler
CC =		clang
CFLAGS =	-Wall -Werror -Wextra -fmodules
CPPFLAGS =	-I $(INC_DIR)
DEPFLAGS =	-MMD

# Libraries
LDLIBS =	-framework CoreDisplay

# Commands
RM =		rm -f
RMDIR =		rm -rf
MKDIR =		mkdir -p
MAKE =		make -C

# Paths
INC_DIR =	headers

SRC_DIR =	sources
SOURCES =	i2c \
			ioregistry \
			m1ddc \

OBJ_DIR =	.objects
OBJECTS = 	$(patsubst %,$(OBJ_DIR)/%,$(SOURCES:=.o))

BIN_DIR =	/usr/local/bin

# -- IMPLICIT RULES / LINKING

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.m Makefile
	@$(CC) -c $< -o $@ $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS)

# -- RULES

all: $(NAME)

$(NAME): $(OBJ_DIR) $(OBJECTS)
	@$(CC) $(LDLIBS) $(OBJECTS) -o $@
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

install:
	/bin/mkdir -p $(BIN_DIR)
	sudo /usr/bin/install -s -m 0755 $(NAME) $(BIN_DIR)

.PHONY: all clean fclean re

-include $(OBJECTS:.o=.d)

