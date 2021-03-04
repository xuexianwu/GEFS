#!/bin/ksh
#

set -x
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
module load gempak/$gempak_ver


module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List
export IOBUF_PARAMS=cfi*:size=64M:count=4:verbose
export FORT_BUFFERED=TRUE
export MKL_CBWR=AVX

#export total_tasks=8
#export OMP_NUM_THREADS=1
#export taskspernode=8

# export for development runs only begin
#export envir=${envir:-dev}
#export RUN_ENVIR=${RUN_ENVIR:-dev}

#export gefsmpexec_mpmd="mpirun -n $total_tasks cfp mpmd_cmdfile"

#. $GEFS_ROCOTO/parm/setbase
#. $GEFS_ROCOTO/parm/gefs_config
#. $GEFS_ROCOTO/parm/gefs_dev.parm

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_GEMPAK_META

