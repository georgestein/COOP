SHELL = /bin/sh

TYPEDEF=../typedef
UTILS=../utils
BACKGROUND=../background
FIRSTORDER=../firstorder

include ../configure.in
include ../compile_rules.in

OBJ = lattice_fields.o 
$(LIB): libcooplattice.a

default: HLattice

$(LIB):	$(OBJ) 
	ar -r $@ $?

BG: $(OBJ) get_background.o
	$(FC) $(FFLAGS) $(INCLUDE) -o $@ $(OBJ) get_background.o $(LINK)

HLattice: $(OBJ) runlattice.o
	$(FC) $(FFLAGS) $(INCLUDE) -o $@ $(OBJ) runlattice.o $(LINK)

clean:
	rm -f *.o *.*~ *.mod \#* *.a Makefile~  HLattice

runlattice.o: lattice_fields.o

