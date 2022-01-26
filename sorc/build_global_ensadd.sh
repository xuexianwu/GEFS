#! /usr/bin/env bash
set -eux

debug=${debug:-NO} # YES, NO

source ./machine-setup.sh
cwd=`pwd`

progname=global_ensadd

if [ -f ../modulefiles/gefs/gefs_$target.ver ]; then
    source ../modulefiles/gefs/gefs_$target.ver
else
    if [ -f ../versions/build.ver ]; then
        source ../versions/build.ver
    fi
fi
source ../modulefiles/gefs/${progname}.$target

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

#
cd ${progname}.fd

export FCMP=${FCMP:-ifort}
export FCMP95=$FCMP

if [ $debug = YES ] ; then
    export FFLAGSM="-O0 -convert big_endian"
    export DEBUG="-g -check all -ftrapuv -fp-stack-check -fstack-protector -heap-arrays -recursive -traceback"
else
    export FFLAGSM="-O3 -convert big_endian"
    export DEBUG=""
fi
export FFLAGSM="${FFLAGSM} ${DEBUG}"
export RECURS=
export LDFLAGSM=${LDFLAGSM:-""}
export OMPFLAGM=${OMPFLAGM:-""}

export INCSM="-I ${G2_INC4}"

export LIBSM="${G2_LIB4} ${W3NCO_LIB4} ${BACIO_LIB4} ${JASPER_LIB} ${PNG_LIB} ${Z_LIB}"

make -f Makefile clobber
make -f Makefile
make -f Makefile install
make -f Makefile clobber

exit
