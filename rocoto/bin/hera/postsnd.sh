#!/bin/ksh
#

# EXPORT list here
set -x
export IOBUF_PARAMS=
ulimit -s unlimited
ulimit -a

# module_ver.h
. $GEFS_ROCOTO/dev/versions/run_hera.ver

# Load modules
. /apps/lmod/lmod/init/ksh
module list
module purge

module use -a /scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles

module load EnvVars/$EnvVars_ver
module load intel/$ips_ver
module load impi/$impi_ver
module load prod_util/$prod_util_ver
#module load prod_envir/$prod_envir_ver
module load gempak/$gempak_ver

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List

export MP_SHARED_MEMORY=yes
export MEMORY_AFFINITY=core:2

#export NODES=3
#export total_tasks=9
#export OMP_NUM_THREADS=2
#export taskspernode=12

export ERRSCRIPT=" "

# export for development runs only begin

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_POSTSND
