#! /usr/bin/env bash
set -eux

source ./machine-setup.sh #> /dev/null 2>&1
cwd=`pwd`

progname=gefs_anom2_fcst

if [ -f ../modulefiles/gefs/gefs_$target.ver ]; then
    source ../modulefiles/gefs/gefs_$target.ver
fi
source ../modulefiles/gefs/${progname}.$target #> /dev/null 2>&1


# Check final exec folder exists
if [ ! -d "../exec" ]; then
    mkdir ../exec
fi

#
cd ${progname}.fd

export FCMP=${FCMP:-ifort}
export FCMP95=$FCMP

#export FFLAGSM="-i4 -O3 -r8  -convert big_endian -fp-model precise"
export FFLAGSM="-O3 -g -convert big_endian"
export RECURS=
export LDFLAGSM=${LDFLAGSM:-""}
export OMPFLAGM=${OMPFLAGM:-""}

export INCSM="-I ${G2_INC4}"

export LIBSM="${W3NCO_LIB4} ${BACIO_LIB4}"

make -f Makefile clobber
make -f Makefile
make -f Makefile install
make -f Makefile clobber

exit
