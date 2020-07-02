#!/bin/ksh

echo "$(date -u) begin ${.sh.file}"

if [[ ${STRICT:-NO} == "YES" ]]; then
    # Turn on strict bash error checking
    set -eu
fi

################################################################################
#   Script:	exgefs_init_recenter.sh.sms
#
#   Author:	Xiaqiong Zhou
#   Date:	2018 March 08
#        April 2018, Dingchen Hou: Slight modification for consistency of the cold start part
#        May 8 2018, Dingchen Hou: Added function for enkf membership shifting with the 4 cucles
#        May 8 2018, Dingchen Hou: Added function to allow fleximble ensemble size
#        April 2018, Bing Fu: Added the warm start part
#        May 11 2018: Dingchen Hou: Added enkf membership shifting and flexible gefs membership 
#        April, 2019: Xiaqiong Zhou: Added new recenter method with NETCDF files
#        May 2, 2019: Dingchen Hou: Dropped off the old recenter methods with NEMSIO files
#        May 3, 2019: Dingchen Hou: Cleaning the script by remove commented lines
#
#    Abstract:	Creates initial conditions for the global ensemble (GEFS) from FV3 based enkf
#		6-h forecast nemsio files 
#		Cold start: Recenter the 6 hour forecast to gfs analysis (nemsio) file
#			The resulted nemsio files need to changed to netCDF in init_fv3chgres jobs
#		Warm start: Generate  increment file (netCDF format) for the ensemble members 
#			from the ensemble mean forecast and gfs analysis, for the encemble contro;
#                        from enkf member npert+1 forecast and gfs analysis
#                	The netCDF format increment files will be used in the forecast job, together
#			with RESTAT files  
#
################################################################################

echo " ------------------------------------------------------------"
echo "  "
echo "            GLOBAL ENSEMBLE INITIALIZATION "
echo "  "
echo "                $(date)     "
echo "  "
echo "                   JOB  $job  "
echo "  "
echo "  "
echo "               FORECAST cycle TIME is $cycle"
echo "  "
echo " ------------------------------------------------------------"
echo "          processing info for this execution"
echo " Home directory is ............................ $HOMEgefs"
echo " Processing directory for files.. ............. $DATA"
echo "  "
echo " Network id is ................................ $NET"
echo " Run id for com processing is ................. $RUN"
echo "  "
echo " standard output in file ...................... $pgmout"
echo " YES SENDCOM means save com files ............. $SENDCOM"
echo " ------------------------------------------------------------"

export warm_start=${warm_start:-"false"}

echo "DATA=$DATA"

# Set environment.
VERBOSE=${VERBOSE:-"YES"}
if [ $VERBOSE = "YES" ]; then
   echo "$(date) EXECUTING ${.sh.file} $*" >&2
   set -x
fi

export CASE=${CASE:-384}
ntiles=${ntiles:-6}

# Utilities
ERRSCRIPT=${ERRSCRIPT:-'eval [[ $err = 0 ]]'}
NCP=${NCP:-"/bin/cp -p"}
NLN=${NLN:-"/bin/ln -sf"}
NMV=${NMV:-"/bin/mv -uv"}

# Scripts
RECENATMPY=${RECENATMPY:-$HOMEgefs/util/ush/recentensemble.py}

export err=0
if [ $warm_start = ".false." ]; then
	export FILENAME='gfs_data.tile'
	export FILEINPATH=$GESIN/enkf
	export FILEOUTPATH=$GESOUT/init

    mkdir -p $FILEOUTPATH/c00
 	$NCP $FILEINPATH/c00/gfs*  $FILEOUTPATH/c00/.

    if [ $npert -gt 0 ]; then
        rm -rf poescript*

        (( itile = 1 ))
        while (( itile <= ntiles  )); do
    		echo "$RECENATMPY $npert $ntiles $FILENAME $FILEINPATH $FILEOUTPATH $itile" >>poescript
            (( itile = itile + 1 ))
        done # while (( itask < npert ))

        chmod 755 poescript
        ls -al poescript
        cat poescript
        export MP_HOLDTIME=1000

        export MP_CMDFILE=poescript
        export SCR_CMDFILE=$MP_CMDFILE  # Used by mpiserial on Theia
        export MP_LABELIO=yes
        export MP_INFOLEVEL=3
        export MP_STDOUTMODE=unordered
        export MP_PGMMODEL=mpmd

        if [ -f mpmd_cmdfile ]; then 
            rm mpmd_cmdfile
        fi
        ln -s $MP_CMDFILE mpmd_cmdfile
        $APRUN_MPMD
        
        export err=$?
        if [[ $err != 0 ]]; then
            echo "FATAL ERROR in ${.sh.file}: One or more recenter jobs in $MP_CMDFILE failed!"
            exit $err
        fi
    fi
else
	echo "FATAL ERROR in ${.sh.file}: init_recenter only works for cold start"
    exit 1
fi # $warm_start = ".false."

if [[ $SENDCOM == YES ]]; then
    mem=01
    while [ $mem -le $npert ]; do
        smem=p$(printf %02i $mem)
        mkdir -p $COMOUT/init/$smem
        $NCP $GESOUT/init/$smem/gfs* $COMOUT/init/$smem
	if [[ $SENDDBN = YES ]];then
	    $DBNROOT/bin/dbn_alert MODEL ENS_SA_$smem $job $COMOUT/init/$smem/gfs_data.tile6.nc
	fi		
        (( mem = mem +1 ))
    done
fi

rm -rf $GESOUT/enkf
echo "$(date -u) end ${.sh.file}"

exit 0
