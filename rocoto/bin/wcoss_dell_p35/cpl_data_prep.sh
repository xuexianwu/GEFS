#!/bin/bash

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
#module load HDF5-parallel/$HDF5_parallel_ver
#module load NetCDF-parallel/$NetCDF_parallel_ver

module load lsf/$lsf_ver

#module load CFP/$CFP_ver
#export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/wcoss_dell_p35/common.sh

#set -x

###############################################################
## Abstract:
## Create FV3 initial conditions from GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source FV3GFS workflow modules
#HOMEgfs=/scratch2/NCEPDEV/ensemble/Bing.Fu/git/gw_cplp5_050
#export RUNDIR=$WORKDIR/tmpnwprd
#export EXPDIR=/scratch2/NCEPDEV/ensemble/Bing.Fu/p5/test050
#export BASE_ENV=$HOMEgfs/env
export CDATE=${PDY}00

#. $HOMEgfs/ush/load_fv3gfs_modules.sh
#status=$?
#[[ $status -ne 0 ]] && exit $status

#. $GEFS_ROCOTO/bin/wcoss_dell_p35/common.sh

#export DATAROOT="$ROTDIR"
#[[ ! -d $DATAROOT ]] && mkdir -p $DATAROOT

###############################################################
# Source relevant configs
configs="base fv3ic wave"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

export jobid=${jobid:-"$job.$LSB_JOBID"}
export GESOUT=$GESROOT/${envir}/${RUN}.${PDY}/$cyc

export DATA=${DATA:-${DATAROOT}/${jobid}}

export RUNDIR=${DATA} #$WORKDIR/tmpnwprd/gefs.$PDY/$cyc
export ICSDIR=${GESOUT}/init #$COMROOT/gens/dev/gefs.$PDY/$cyc
export ROTDIR=$RUNDIR
export DATAROOT=$RUNDIR
mkdir -p $ICSDIR
mkdir -p $ROTDIR

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env fv3ic
status=$?
[[ $status -ne 0 ]] && exit $status

if [ $ICERES = '025' ]; then
  ICERESdec="0.25"
fi 
if [ $ICERES = '050' ]; then         
 ICERESdec="0.50"        
fi 
p5_025icdir=/gpfs/dell6/emc/modeling/noscrub/Bing.Fu/p5_025ic
atminitdir=$p5_025icdir/gfs
ocninitdir=$p5_025icdir/ocn
iceinitdir=$p5_025icdir/ice
wavinitdir=$p5_025icdir/wav
for mem in $MEMLIST
do

    # Create ICSDIR if needed
    [[ ! -d $ICSDIR/$mem/FV3ICS/gfs/$CASE/INPUT ]] && mkdir -p $ICSDIR/$mem/gfs/$CASE/INPUT
    [[ ! -d $ICSDIR/$mem/FV3ICS/ocn ]] && mkdir -p $ICSDIR/$mem/ocn
    [[ ! -d $ICSDIR/$mem/FV3ICS/ice ]] && mkdir -p $ICSDIR/$mem/ice

    # Setup ATM initial condition files
    #cp -r $ORIGIN_ROOT/$CPL_ATMIC/$CDATE/$CDUMP  $ICSDIR/$CDATE/
    cp -r $atminitdir/gefs.$PDY/$cyc/$mem/*  $ICSDIR/$mem/gfs/$CASE/INPUT

    # Setup Ocean IC files 
    #cp -r $ORIGIN_ROOT/$CPL_OCNIC/$CDATE/ocn/$OCNRES/MOM*.nc  $ICSDIR/$CDATE/ocn/
    #cp -r $cplinit/$CDATE/050/ocn  $ICSDIR/$mem/FV3ICS
    cp -r $ocninitdir/$PDY/MOM4_TS_restart_regular.nc $ICSDIR/$mem/ocn/MOM6_IC_TS.nc
    #Setup Ice IC files 
    #cp $ORIGIN_ROOT/$CPL_ICEIC/$CDATE/ice/$ICERES/cice5_model_${ICERESdec}.res_$CDATE.nc $ICSDIR/$CDATE/ice/
    #cp -r $cplinit/$CDATE/050/ice $ICSDIR/$mem/FV3ICS
    cp -r $iceinitdir/cice5_model_0.25.res_${CDATE}.nc $ICSDIR/$mem/ice/cice5_model_0.25.res_${CDATE}.nc
    if [ $cplwav = ".true." ]; then
        [[ ! -d $ICSDIR/$mem/FV3ICS/wav ]] && mkdir -p $ICSDIR/$mem/wav
        #  for grdID in $waveGRD
        #  do
        #cp $ORIGIN_ROOT/$CPL_WAVIC/$CDATE/wav/$grdID/*restart.$grdID $ICSDIR/$CDATE/wav/
        cp -r $wavinitdir/${PDY}.000000.restart.gwes_30m $ICSDIR/$mem/wav
        #echo no wave initial data at this time
        #  done
    fi

    export OUTDIR="$ICSDIR/$mem/gfs/$CASE/INPUT"
    mkdir -p $ICSDIR/ocndaily/$mem
    # Stage the FV3 initial conditions to ROTDIR
    memCOMOUT="$ROTDIR/$mem"
    [[ ! -d $memCOMOUT ]] && mkdir -p $memCOMOUT
    cd $memCOMOUT || exit 99
    rm -rf INPUT
    #$NLN $OUTDIR .
done

##############################################################
# Exit cleanly
#exit 0
##############################
# Remove the Temporary working directory
##############################
cd $DATAROOT
if [ ${KEEPDATA:-NO} = NO ] ; then rm -rf $DATA ; fi

echo "$(date -u) end $(basename $BASH_SOURCE)"

exit $err

