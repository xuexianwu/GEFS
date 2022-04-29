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
module load gempak/$gempak_ver


module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List
export MP_SHARED_MEMORY=no
export MEMORY_AFFINITY=core:6

#export NODES=$SLURM_JOB_NUM_NODES
#export total_tasks=$SLURM_NTASKS
#export OMP_NUM_THREADS=1
#export taskspernode=$SLURM_CPUS_ON_NODE


# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_GEMPAK

