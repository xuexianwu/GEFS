#!/bin/ksh
#

# EXPORT list here
set -x
export IOBUF_PARAMS=
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/gefs_hera.ver

# Load modules
. /apps/lmod/lmod/init/ksh
module list
module purge

module use -a /scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles

module load EnvVars/$EnvVars_ver
module load intel/$ips_ver
module load impi/$impi_ver
module load prod_util/$prod_util_ver

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List
export MP_SHARED_MEMORY=no
export MEMORY_AFFINITY=core:6

#export total_tasks=6
#export OMP_NUM_THREADS=6
#export taskspernode=4

#export FORECAST_SEGMENT=hr

#export NTHREADS_SIGCHGRS=6
#
# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_ENSAVG_NEMSIO

