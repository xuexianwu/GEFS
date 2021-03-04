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

#export ATP_ENABLED=0
#export MALLOC_MMAP_MAX_=0
#export MALLOC_TRIM_THRESHOLD_=134217728

#export MPICH_ABORT_ON_ERROR=1
#export MPICH_ENV_DISPLAY=1
#export MPICH_VERSION_DISPLAY=1
#export MPICH_CPUMASK_DISPLAY=1
#
#export KMP_STACKSIZE=1024m

#export MP_EUIDEVICE=sn_all
#export MP_EUILIB=us
#export MP_SHARED_MEMORY=no
#export MEMORY_AFFINITY=core:4

#export total_tasks=1
#export OMP_NUM_THREADS=1
#export taskspernode=1

# export for development runs only begin
#export envir=${envir:-dev}
#export RUN_ENVIR=${RUN_ENVIR:-dev}

#export gefsmpexec_mpmd="mpirun -n $total_tasks cfp mpmd_cmdfile"

#. $GEFS_ROCOTO/parm/setbase
#. $GEFS_ROCOTO/parm/gefs_config
#. $GEFS_ROCOTO/parm/gefs_dev.parm

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_AVGSPR_GEMPAK_META

