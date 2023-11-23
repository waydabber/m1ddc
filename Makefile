# -- VARIABLES

# Project name
NAME =		m1ddc
LIB = 		lib$(NAME)

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
AR =		ar -rcs

# Paths
INC_DIR =	headers
SRC_DIR =	sources
LIB_DIR =	library
BIN_DIR =	/usr/local/bin

# Sources & Objects - Binary
SOURCES =	i2c \
			ioregistry \
			m1ddc \

OBJ_DIR =	.objects
OBJECTS = 	$(patsubst %,$(OBJ_DIR)/%,$(SOURCES:=.o))

# Sources & Objects - Library
LIB_SRCS = 	$(filter-out m1ddc, $(SOURCES))
LIB_OBJS = 	$(patsubst %,$(OBJ_DIR)/%,$(LIB_SRCS:=.o))
LIB_HDRS = 	$(patsubst %,$(INC_DIR)/%,$(LIB_SRCS:=.h))

# -- IMPLICIT RULES / LINKING

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.m Makefile
	@$(CC) -c $< -o $@ $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS)

$(OBJ_DIR):
	@$(MKDIR) $(OBJ_DIR)

$(LIB_DIR):
	@$(MKDIR) $(LIB_DIR)

$(NAME): $(OBJ_DIR) $(OBJECTS)
	@$(CC) $(LDLIBS) $(OBJECTS) -o $@
	@printf "Created binary \"$(NAME)\"\n"

$(LIB).a: $(LIB_DIR) $(OBJ_DIR) $(LIB_OBJS)
	@$(AR) $(LIB_DIR)/$@ $(LIB_OBJS)
	@printf "Created library \"$(LIB_DIR)/$@\"\n"

# For each header file, we do the following, using regular expressions:
# - Ignore the #ifndef _FILE/# define _FILE/#endif directives that begin/end the file
# - Extract the #import directives
# - Extract all the remaining # directives
# - Extract the rest: types and functions declarations.
# All the extracted lines are then appendend to the final header file.
$(LIB).h: $(LIB_DIR) $(LIB_HDRS)
	@imports=""; \
	directives=""; \
	declarations=""; \
	for file in $(LIB_HDRS); do \
		declarations="$$declarations\n\n/*\n * -- $$(basename $$file .h | tr '[:lower:]' '[:upper:]')\n*/\n"; \
		fileguard=$$(echo "_$$(basename $$file .h | tr '[:lower:]' '[:upper:]')_H"); \
		if [ "$$(head -n 1 $$file)" = "#ifndef $$fileguard" ]; then \
			filecontent=$$(sed -e '1,2d' -e '$$d' $$file); \
		else \
			filecontent=$$(cat $$file); \
		fi; \
		imports="$$imports\n$$(echo "$$filecontent" | grep -E "^#\s*import" | sort | uniq)"; \
		directives="$$directives\n$$(echo "$$filecontent" | grep -E "^#" | grep -vE "^#\s*import" | grep -vE "^#\s*include\s*\".*.h\"$$" )"; \
		declarations="$$declarations\n$$(echo "$$filecontent" | grep -vE "^#" )"; \
	done; \
	guard=$$(echo "_$(LIB)_H" | tr '[:lower:]' '[:upper:]'); \
	printf "#ifndef $$guard\n# define $$guard\n\n" > $(LIB_DIR)/$@; \
	printf "$$directives\n\n" >> $(LIB_DIR)/$@; \
	printf "$$imports\n\n" >> $(LIB_DIR)/$@; \
	printf "$$declarations\n\n" >> $(LIB_DIR)/$@; \
	printf "#endif" >> $(LIB_DIR)/$@; \
	sed -i '' -e '/^$$/N;/^\n$$/D' $(LIB_DIR)/$@; \

	@printf "Created header \"$(LIB_DIR)/$@\"\n"

# -- RULES

.DEFAULT_GOAL := binary

all: binary lib

binary: $(NAME)

lib: $(LIB).a $(LIB).h

clean:
	@if [ -e $(OBJ_DIR) ]; then \
		$(RMDIR) $(OBJ_DIR); \
		printf "Objects deleted\n"; \
	fi;

fclean: clean
	@if [ -e $(NAME) ]; then \
		$(RM) $(NAME); \
		printf "Binary deleted\n"; \
	fi;
	@if [ -e $(LIB_DIR) ]; then \
		$(RMDIR) $(LIB_DIR); \
		printf "Library deleted\n"; \
	fi;

re: fclean all

install:
	/bin/mkdir -p $(BIN_DIR)
	sudo /usr/bin/install -s -m 0755 $(NAME) $(BIN_DIR)

.PHONY: all lib clean fclean re install

-include $(OBJECTS:.o=.d)

