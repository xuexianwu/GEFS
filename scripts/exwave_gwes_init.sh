#!/bin/bash
###############################################################################
#                                                                             #
# This script is the init config  for the global multi_grid wave model. It    #
# creates model definition files with all configurations of spatial and       #
# spectral grids, as well as set general physics parameters and time steps.   #
#                                                                             #
# The main script for generating mod_def files is                             #
#  wave_moddef.sh : creates the mod_def file for the grid                     #
#                                                                             #
# Remarks :                                                                   #
# - For non-fatal errors output is witten to the wave.log file.               #
#                                                                             #
#  Update record :                                                            #
#                                                                             #
# - Origination:                                               02-Apr-2019    #
# - Transitioning to GEFS workflow                             02-May-2019    #
#                                                                             #
###############################################################################
# --------------------------------------------------------------------------- #
# 0.  Preparations
# 0.a Basic modes of operation

  set -x
  # Use LOUD variable to turn on/off trace.  Defaults to YES (on).
  export LOUD=${LOUD:-YES}; [[ $LOUD = yes ]] && export LOUD=YES
  [[ "$LOUD" != YES ]] && set +x

  cd $DATA

  msg="HAS BEGUN on `hostname`"
  postmsg "$jlogfile" "$msg"
  msg="Starting MWW3 INIT CONFIG SCRIPT for $wavemodID"
  postmsg "$jlogfile" "$msg"

  set +x
  echo ' '
  echo '                      ********************************'
  echo '                      *** MWW3 INIT CONFIG  SCRIPT ***'
  echo '                      ********************************'
  echo '                          Initial configuration script'
  echo "                          Model identifier : $wavemodID"
  echo ' '
  echo "Starting at : `date`"
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

# Script will run only if pre-defined NTASKS
#     The actual work is distributed over these tasks.
  if [ -z ${NTASKS} ] 
  then
    echo "FATAL ERROR: requires NTASKS to be set "
    err=999; export err;${errchk}
  fi

  set +x
  echo ' '
  echo " Script set to run with $NTASKS tasks "
  echo ' '
  [[ "$LOUD" = YES ]] && set -x


# --------------------------------------------------------------------------- #
# 1.  Get files that are used by most child scripts

  set +x
  echo 'Preparing input files :'
  echo '-----------------------'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

# 1.a Model definition files

  nmoddef=0

  rm -f cmdfile
  touch cmdfile
  chmod 744 cmdfile

# Eliminate duplicate grids
  array=($curID $iceID $wndID $buoy $waveGRD $esmfGRD $sbsGRD $postGRD $interpGRD)
  grdALL=`printf "%s\n" "${array[@]}" | sort -u | tr '\n' ' '`

  for grdID in ${grdALL}
  do
    if [ -f "$COMIN/rundata/${wavemodID}.mod_def.${grdID}" ]
    then
      set +x
      echo " Mod def file for $grdID found in ${COMIN}/rundata. copying ...."
      [[ "$LOUD" = YES ]] && set -x
      cp $COMIN/rundata/${wavemodID}.mod_def.${grdID} mod_def.$grdID

    else
      set +x
      echo " Mod def file for $grdID not found in ${COMIN}/rundata. Setting up to generate ..."
      [[ "$LOUD" = YES ]] && set -x
      if [ -f $FIXwave/ww3_$grdID.inp ]
      then
        cp $FIXwave/ww3_$grdID.inp $grdID.inp
      fi

      if [ -f $grdID.inp ]
      then
        set +x
        echo ' '
        echo "   $grdID.inp copied ($FIXwave/ww3_$grdID.inp)."
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      else
        msg="ABNORMAL EXIT: NO INP FILE FOR MODEL DEFINITION FILE"
        postmsg "$jlogfile" "$msg"
        set +x
        echo ' '
        echo '*********************************************************** '
        echo '*** FATAL ERROR : NO INP FILE FOR MODEL DEFINITION FILE *** '
        echo '*********************************************************** '
        echo "                                grdID = $grdID"
        echo ' '
        echo $msg
        [[ "$LOUD" = YES ]] && set -x
        echo "$wavemodID init config $date $cycle : $grdID.inp missing." >> $wavelog
        err=1;export err;${errchk}
      fi

      echo "$USHwave/wave_moddef.sh $grdID > $grdID.out 2>&1" >> cmdfile

      nmoddef=`expr $nmoddef + 1`

    fi
  done

# 1.a.1 Execute parallel or serialpoe 

  if [ "$nmoddef" -gt '0' ]
  then

    set +x
    echo ' '
    echo " Generating $nmoddef mod def files"
    echo ' '
    [[ "$LOUD" = YES ]] && set -x

# Set number of processes for mpmd
    wavenproc=`wc -l cmdfile | awk '{print $1}'`
    wavenproc=`echo $((${wavenproc}<${NTASKS}?${wavenproc}:${NTASKS}))`

# 1.a.3 Execute the serial or parallel cmdfile

    set +x
    echo ' '
    echo "   Executing the copy command file at : `date`"
    echo '   ------------------------------------'
    echo ' '
    [[ "$LOUD" = YES ]] && set -x
  
    if [ "$NTASKS" -gt '1' ]
    then
      ${wavempexec} ${wavenproc} ${wave_mpmd} cmdfile
      exit=$?
    else
      ./cmdfile
      exit=$?
    fi
  
    if [ "$exit" != '0' ]
    then
      set +x
      echo ' '
      echo '********************************************'
      echo '*** POE FAILURE DURING RAW DATA COPYING ***'
      echo '********************************************'
      echo '     See Details Below '
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
    fi
  
  fi 

# 1.a.3 File check

  for grdID in $curID $iceID $wndID $waveGRD $esmfGRD $sbsGRD $postGRD $interpGRD
  do
    if [ -f mod_def.$grdID ]
    then
      set +x
      echo ' '
      echo " mod_def.$grdID succesfully created/copied "
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
    else 
      msg="ABNORMAL EXIT: NO MODEL DEFINITION FILE"
      postmsg "$jlogfile" "$msg"
      set +x
      echo ' '
      echo '********************************************** '
      echo '*** FATAL ERROR : NO MODEL DEFINITION FILE *** '
      echo '********************************************** '
      echo "                                grdID = $grdID"
      echo ' '
      echo $msg
      sed "s/^/$grdID.out : /g"  $grdID.out
      [[ "$LOUD" = YES ]] && set -x
      echo "$wavemodID prep $date $cycle : mod_def.$grdID missing." >> $wavelog
      err=2;export err;${errchk}
    fi
  done

# --------------------------------------------------------------------------- #
# 2.  Ending 

  set +x
  echo ' '
  echo "Ending at : `date`"
  echo ' '
  echo '                     *** End of MWW3 Init Config ***'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  msg="$job completed normally"
  postmsg "$jlogfile" "$msg"

# End of MWW3 init config script ------------------------------------------- #
