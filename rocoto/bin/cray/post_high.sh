#!/bin/ksh
#

# EXPORT list here
set -x

export IOBUF_PARAMS=
export FORT_BUFFERED=TRUE
export MKL_CBWR=AVX
ulimit -s unlimited
ulimit -a

export ATP_ENABLED=0
export MALLOC_MMAP_MAX_=0
export MALLOC_TRIM_THRESHOLD_=134217728

export MPICH_ABORT_ON_ERROR=1
export MPICH_ENV_DISPLAY=1
export MPICH_VERSION_DISPLAY=1
export MPICH_CPUMASK_DISPLAY=1

export KMP_STACKSIZE=1024m
export OMP_NUM_THREADS=2
export KMP_AFFINITY=disabled

#export OMP_NUM_THREADS=2
export KMP_AFFINITY=disabled

export MP_EUIDEVICE=sn_all
export MP_EUILIB=us
export MP_SHARED_MEMORY=yes
export MEMORY_AFFINITY=core:2

export NODES=2
export total_tasks=24
export OMP_NUM_THREADS=2
export taskspernode=24
export POSTGRB2TBL=$G2TMPL_SRC/params_grib2_tbl_new
export OMP_STACKSIZE=2048M
export FORECAST_SEGMENT=hr

export envir=${envir:-dev}
export RUN_ENVIR=${RUN_ENVIR:-dev}



export gefsmpexec=" aprun -b -j1 -n24 -N12 -d2 -cc depth "

# CALL executable job script here




$SOURCEDIR/jobs/JGEFS_NCEPPOST
