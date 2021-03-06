#!/bin/bash
platform=intel64
dir=`pwd`
target=${dir##*/}

source $IFORT_COMPILER/bin/compilervars.sh $platform
source ../Scripts/set_mpidist.sh /shared/openmpi_64ib
if [ "$MPIDIST" == "" ]; then
  exit
fi

echo Building $target 
make -j4 VPATH="../../FDS_Source" -f ../makefile $target
