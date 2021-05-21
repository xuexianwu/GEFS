#!/bin/bash
##!/bin/ksh -x
##!/bin/bash

set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/gefs_wcoss_dell_p35.ver

# Load modules
. /usrx/local/prod/lmod/lmod/init/ksh
module list
module purge

module load EnvVars/$EnvVars_ver
module load ips/$ips_ver
module load impi/$impi_ver
module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver

module load lsf/$lsf_ver

module load CFP/$CFP_ver
export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/wcoss_dell_p35/common.sh

# Export List

# CALL executable job script here
#$SOURCEDIR/jobs/JGEFS_WAVE_INIT


###############################################################
#echo
#echo "=============== START TO SOURCE FV3GFS WORKFLOW MODULES ==============="
#. $HOMEgfs/ush/load_fv3gfs_modules.sh
#status=$?
#[[ $status -ne 0 ]] && exit $status

#export DATAROOT="$WORKDIR/tmpnwprd/gefs.$PDY/$cyc"
#[[ ! -d $DATAROOT ]] && mkdir -p $DATAROOT
#export DATA_DIR="$WORKDIR/com/gens/dev"
###############################################################
echo
echo "=============== START TO RUN WAVE INIT ==============="
# Execute the JJOB
$HOMEgfs/jobs/JGLOBAL_WAVE_INIT
status=$?
exit $status

