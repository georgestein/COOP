#! /bin/bash
make clean
cd typedef 
make clean
cd ../utils
make clean
cd ../background
make clean
cd ../firstorder
make clean
cd ../lib
make clean
cd ../test
make clean
cd ../mapio
make clean
cd ..
cd ../include
rm -f *.mod \#*\# *.*~
make clean
