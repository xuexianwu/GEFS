#!/bin/bash
###############################################################################
#                                                                             #
# This script is the preprocessor for the global multi_grid wave model. It    #
# sets some shell script variables for export to child scripts and copies     #
# some generally used files to the work directory. After this the actual      #
# preprocessing is performed by the following child scripts :                 #
#                                                                             #
#  wave_ice.sh     : preprocess ice fields.                                   #
#  wave_rtofs     : preprocess rtofs current fields.                          #
#  wave_g2ges.sh  : find and copy wind grib2 files.                           #
#                                                                             #
# Remarks :                                                                   #
# - For non-fatal errors output is witten to the wave.log file.               #
#                                                                             #
#  Update record :                                                            #
#                                                                             #
# - Origination:                                               01-Mar-2007    #
# - Added NCO note on resources on mist/dew.                   05-Mar-2007    #
# - Renmaing mod_def files in $FIX_wave.                       26-Apr-2007    #
# - Migrating to a vertical structure                          28-Mar-2011    #
# - Transitioning to WCOSS                                     30-Nov-2012    #
# - Adding wave-current interactions, new two polar grids, 1/4 degree res     #
#                                                              10-Jan-2018    #
# - Transitioning to GEFS workflow                              2-Apr-2019    #
#                                                                             #
#   wavemodID and wavemodTAG replace modID. wavemodTAG                        # 
#   is used for ensemble-specific I/O. For deterministic                      #
#   wavemodID=wavemodTAG                                                      # 
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
  mkdir outtmp

  msg="HAS BEGUN on `hostname`"
  postmsg "$jlogfile" "$msg"
  msg="Starting MWW3 PREPROCESSOR SCRIPT for $wavemodTAG"
  postmsg "$jlogfile" "$msg"

  set +x
  echo ' '
  echo '                      ********************************'
  echo '                      *** MWW3 PREPROCESSOR SCRIPT ***'
  echo '                      ********************************'
  echo '                          Global multi-grid model with GFS forcing'
  echo "                          Model identifier : $wavemodTAG "
  echo ' '
  echo "Starting at : `date`"
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

#  export MP_PGMMODEL=mpmd
#  export MP_CMDFILE=./cmdfile

  if [ "$INDRUN" = 'no' ]
  then
    wavlsth=${wavlsth:-3}
  else
    wavlsth=${wavlsth:-384}
  fi

# 0.b Date and time stuff

  export date=$PDY
  export YMDH=${PDY}${cyc}

  ymdh_beg=`$NDATE -$HINDH $YMDH`
  time_beg="`echo $ymdh_beg | cut -c1-8` `echo $ymdh_beg | cut -c9-10`0000"

  ymdh_end=`$NDATE $wavlsth $YMDH`
  time_end="`echo $ymdh_end | cut -c1-8` `echo $ymdh_end | cut -c9-10`0000"

# Restart file times 
  RSTOFFSET=`expr ${CYCSTRIDE} - ${HINDH}`
  ymdh=`$NDATE ${RSTOFFSET} $YMDH`
  time_rst_ini="`echo $ymdh | cut -c1-8` `echo $ymdh | cut -c9-10`0000"
  if [ ${DTRST} -gt 1 ]
  then
    ymdh=`$NDATE $DTRST $ymdh`
    time_rst_end="`echo $ymdh | cut -c1-8` `echo $ymdh | cut -c9-10`0000"
  else
    time_rst_end=${time_rst_ini}
     DTRST=1
  fi

  set +x
  echo ' '
  echo 'Times in wave model format :'
  echo '----------------------------'
  echo "   date / cycle  : $date $cycle"
  echo "   starting time : $time_beg"
  echo "   ending time   : $time_end"
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

# Script will run only if pre-defined NTASKS
#     The actual work is distributed over these tasks.
  if [ -z ${NTASKS} ]        
  then
    echo "FATAL ERROR: Requires NTASKS to be set "
    err=999; export err;${errchk}
  fi

# --------------------------------------------------------------------------- #
# 1.  Get files that are used by most child scripts

  set +x
  echo 'Preparing input files :'
  echo '-----------------------'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

# 1.a Model definition files

  rm -f cmdfile
  touch cmdfile

  grdINP=''
  if [ "${WW3ATMINP}" = 'YES' ]; then grdINP="${grdINP} $wndID" ; fi 
  if [ "${WW3ICEINP}" = 'YES' ]; then grdINP="${grdINP} $iceID" ; fi 
  if [ "${WW3CURINP}" = 'YES' ]; then grdINP="${grdINP} $curID" ; fi 

  ifile=1

  for grdID in $grdINP $waveGRD
  do
    if [ -f "$COMIN/rundata/${wavemodID}.mod_def.${grdID}" ]
    then
      set +x
      echo " Mod def file for $grdID found in ${COMIN}/rundata. copying ...."
      [[ "$LOUD" = YES ]] && set -x
      cp $COMIN/rundata/${wavemodID}.mod_def.${grdID} mod_def.$grdID

    else
      msg="FATAL ERROR: NO MODEL DEFINITION FILE"
      postmsg "$jlogfile" "$msg"
      set +x
      echo ' '
      echo '*********************************************************** '
      echo '*** FATAL ERROR : NOT FOUND WAVE  MODEL DEFINITION FILE *** '
      echo '*********************************************************** '
      echo "                                grdID = $grdID"
      echo ' '
      echo $msg
      [[ "$LOUD" = YES ]] && set -x
      echo "$wavemodID prep $date $cycle : ${wavemodID}.mod_def.${grdID} missing." >> $wavelog
      err=1;export err;${errchk}
    fi
  done

# 1.a.1 Check if mod_defs are available
  for grdID in $grdINP $waveGRD
  do
    if [ -f mod_def.$grdID ]
    then
      set +x
      echo ' '
      echo " mod_def.$grdID succesfully copied "
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

# 1.b Netcdf Preprocessor template files

   for grdID in $grdINP
   do

     case $grdID in
     $currID ) 
              type='curr' 
     ;;
     $wndID )
              type='wind'
     ;;
     $iceID )
              type='ice'
     ;;
     * )
              echo 'Input type not yet implelemted' 	    
              err=3; export err;${errchk}
              ;;
     esac 

     echo 'Working here,TYPE is: '$type


     if [ -f $FIXwave/ww3_prnc.${type}.$grdID.inp.tmpl ]
     then
       cp $FIXwave/ww3_prnc.${type}.$grdID.inp.tmpl .
     fi

     if [ -f ww3_prnc.${type}.$grdID.inp.tmpl ]
     then
       set +x
       echo ' '
       echo "   ww3_prnc.${type}.$grdID.inp.tmpl copied ($FIXwave)."
       echo ' '
       [[ "$LOUD" = YES ]] && set -x
     else
       msg="ABNORMAL EXIT: NO FILE $file"
       ./postmsg "$jlogfile" "$msg"
       set +x
       echo ' '
       echo '************************************** '
       echo '*** FATAL ERROR : NO TEMPLATE FILE *** '
       echo '************************************** '
       echo "             ww3_prnc.${type}.$grdID.inp.tmpl"
       echo ' '
       echo $msg
       echo ' '
       [[ "$LOUD" = YES ]] && set -x
       echo "$wavemodID prep $date $cycle : ww3_prnc.${type}.$grdID.tmpl missing." >> $wavelog
       err=4;export err;${errchk}
     fi
   done

# --------------------------------------------------------------------------- #
# ICEC processing

  if [ "${WW3ICEINP}" = 'YES' ]; then

# --------------------------------------------------------------------------- #
# 2. Ice pre - processing 

# 2.a Check if ice input is perturbed (number of inputs equal to number of wave
#     ensemble members
    if [ "${RUNMEM}" = "-1" ] || [ "${WW3ICEIENS}" = "T" ] || [ "$waveMEMB" = "00" ]
    then

      $USHwave/wave_ice.sh > wave_ice.out 
      ERR=$?
    
      if [ -d ice ]
      then
        postmsg "$jlogfile" "FATAL ERROR ice field not generated."
        set +x
        echo ' '
        echo '      FATAL ERROR: ice field not generated '
        echo ' '
        sed "s/^/ice.out : /g" ice.out
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        err=5;export err;${errchk}
      else
        mv -f ice.out $DATA/outtmp
        rm -f ww3_prep.$iceID.tmpl mod_def.$iceID
        set +x
        echo ' '
        echo '      Ice field unpacking successful.'
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      fi
    else
      echo ' '
      echo " Ice input is not perturbed, single ice file generated, skipping ${wavemodTAG}"
      echo ' '
    fi 
  else
      echo ' '
      echo ' No input ice file generated, this run did not request pre-processed ice data '
      echo ' '
  fi

# --------------------------------------------------------------------------- #
# WIND processing

  if [ "${WW3ATMINP}" = 'YES' ]; then

# --------------------------------------------------------------------------- #
# 3.  Wind pre-processing

    if [ "${RUNMEM}" = "-1" ] || [ "${WW3ATMIENS}" = "T" ] || [ "$waveMEMB" = "00" ]
    then
 
      rm -f cmdfile
      touch cmdfile
      chmod 744 cmdfile
 
# 3.a Gather and pre-process grib2 files 
      ymdh=$ymdh_beg
    
      while [ "$ymdh" -le "$ymdh_end" ]
      do
        echo "$USHwave/wave_g2ges.sh $ymdh > grb_$ymdh.out 2>&1" >> cmdfile
        ymdh=`$NDATE $HOUR_INC $ymdh`
      done
  
# 3.b Execute the serial or parallel cmdfile

# Set number of processes for mpmd
      wavenproc=`wc -l cmdfile | awk '{print $1}'`
      wavenproc=`echo $((${wavenproc}<${NTASKS}?${wavenproc}:${NTASKS}))`
  
      set +x
      echo ' '
      echo "   Executing the copy command file at : `date`"
      echo '   ------------------------------------'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
  
      if [ "$nfile" -gt '1' ]
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
        echo '*** CMDFILE FAILED IN WIND GENERATION   ***'
        echo '********************************************'
        echo '     See Details Below '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      fi
   
# 3.c Check for errors
  
      set +x
      echo ' '
      echo '   Checking for errors.'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
    
#     We will go on if the number of errors in files is less
#     than err_max

      [[ "$LOUD" = YES ]] && set -x
      err_max=1
  
  
      ymdh=$ymdh_beg
      nr_err=0

      set +x
      echo '      Sources of grib2 files :'
      [[ "$LOUD" = YES ]] && set -x
      while [ "$ymdh" -le "$ymdh_end" ]
      do
        if [ -d grb_${ymdh} ]
        then
          set +x
          echo ' '
          echo "         File for $ymdh : error in wave_g2ges.sh"
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          postmsg "$jlogfile" "    File for $ymdh : error in wave_g2ges.sh"
          nr_err=`expr $nr_err + 1`
          rm -f gwnd.$ymdh
        else
          grbfile=`grep 'File for' grb_${ymdh}.out`
          if [ -z "$grbfile" ]
          then
            set +x
            echo ' '
            echo "         File for $ymdh : cannot identify source"
            echo ' '
            [[ "$LOUD" = YES ]] && set -x
            nr_err=`expr $nr_err + 1`
            rm -f gwnd.$ymdh
          else
            if [ ! -f gwnd.$ymdh ]
            then
              set +x
              echo ' '
              echo "         File for $ymdh : file not found"
              echo ' '
              [[ "$LOUD" = YES ]] && set -x
              nr_err=`expr $nr_err + 1`
            else
              set +x
              echo ' '
              echo "      $grbfile"
              echo ' '
              [[ "$LOUD" = YES ]] && set -x
              mv -f grb_${ymdh}.out $DATA/outtmp
            fi
          fi
        fi
        ymdh=`$NDATE $HOUR_INC $ymdh`
      done

      if [ -f grb_*.out ]
      then
        set +x
        echo ' '
        echo '**********************************'
        echo '*** ERROR OUTPUT wave_g2ges.sh ***'
        echo '**********************************'
        echo '            Possibly in multiple calls'
        [[ "$LOUD" = YES ]] && set -x
        echo "$wavemodTAG prep $date $cycle : error in wind grib2 files." >> $wavelog
        set +x
        for file in grb_*.out
        do
          echo ' '
          sed "s/^/$file : /g" $file
        done
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        mv -f grb_*.out $DATA/outtmp
        postmsg "$jlogfile" "NON-FATAL ERROR in wave_g2ges.sh, possibly in multiple calls."
      fi
    
      if [ "$nr_err" -gt "$err_max" ]
      then
        msg="ABNORMAL EXIT: ERROR(S) IN SIGMA FILES"
        postmsg "$jlogfile" "$msg"
        set +x
        echo ' '
        echo '********************************************* '
        echo '*** FATAL ERROR : ERROR(S) IN WIND  FILES *** '
        echo '********************************************* '
        echo ' '
        echo $msg
        [[ "$LOUD" = YES ]] && set -x
        echo "$wavemodTAG prep $date $cycle : fatal error in grib2 wind files." >> $wavelog
        err=6;export err;${errchk}
      fi
  
      rm -f cmdfile

# 3.d Getwind data into single file 

      set +x
      echo ' '
      echo '   Concatenate extracted wind fields ...'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x

      files=`ls gwnd.* 2> /dev/null`

      if [ -z "$files" ]
      then
        msg="ABNORMAL EXIT: NO gwnd.* FILES FOUND"
        postmsg "$jlogfile" "$msg"
        set +x
        echo ' '
        echo '******************************************** '
        echo '*** FATAL ERROR : CANNOT FIND WIND FILES *** '
        echo '******************************************** '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        echo "$wavemodTAG prep $date $cycle : no wind files found." >> $wavelog
        err=7;export err;${errchk}
      fi
  
      rm -f gfs.wind
  
      for file in $files
      do
        cat $file >> gfs.wind
        rm -f $file
      done
  
# 3.e Run ww3_prnc

# Convert gfs wind to netcdf
      $WGRIB2 gfs.wind -netcdf gfs.nc
  
      for grdID in $wndID $curvID
      do
  
        set +x
        echo ' '
        echo "   Running wind fields through preprocessor for grid $grdID"
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
  
        sed -e "s/HDRFL/T/g" ww3_prnc.wind.$grdID.tmpl > ww3_prnc.inp
        ln -sf mod_def.$grdID mod_def.ww3
  
        set +x
        echo "Executing $EXECcode/ww3_prnc"
        [[ "$LOUD" = YES ]] && set -x
  
        $EXECcode/ww3_prnc > prnc.out
        err=$?
  
        if [ "$err" != '0' ]
        then
          msg="ABNORMAL EXIT: ERROR IN waveprnc"
          postmsg "$jlogfile" "$msg"
          set +x
          echo ' '
          echo '*************************************** '
          echo '*** FATAL ERROR : ERROR IN waveprnc *** '
          echo '*************************************** '
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          echo "$wavemodTAG prep $grdID $date $cycle : error in waveprnc." >> $wavelog
          err=8;export err;${errchk}
        fi
  
        if [ ! -f wind.ww3 ]
        then
          msg="ABNORMAL EXIT: FILE wind.ww3 MISSING"
          postmsg "$jlogfile" "$msg"
          set +x
          echo ' '
          cat waveprep.out
          echo ' '
          echo '****************************************'
          echo '*** FATAL ERROR : wind.ww3 NOT FOUND ***'
          echo '****************************************'
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          echo "$wavemodTAG prep $grdID $date $cycle : wind.ww3 missing." >> $wavelog
          err=9;export err;${errchk}
        fi

        rm -f mod_def.ww3
        rm -f ww3_prep.inp

        mv wind.ww3 wind.$grdID
        mv times.WND times.$grdID

# 3.f Check to make sure wind files are properly incremented

        first_pass='yes'
        windOK='yes'
        while read line
        do
          date1=`echo $line | cut -d ' ' -f 1`
          date2=`echo $line | cut -d ' ' -f 2`
          ymdh="$date1`echo $date2 | cut -c1-2`"
          if [ "$first_pass" = 'no' ]
          then
            hr_inc=`$NHOUR $ymdh $ymdh_prev`
            if [ "${hr_inc}" -gt "${HOUR_INC}" ]
            then
              set +x
              echo "Incorrect wind forcing increment at $ymdh" 
              [[ "$LOUD" = YES ]] && set -x
              windOK='no'
            fi
          fi
          ymdh_prev=$ymdh
          first_pass='no'
        done < times.$grdID
  
        if [ "$windOK" = 'no' ]
        then
          set +x
          echo ' '
          echo '************************************************'
          echo '*** ERROR : WIND DATA INCREMENT INCORRECT !! ***'
          echo '************************************************'
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          echo "$wavemodTAG prep $grdID $date $cycle : error in wind increment." >> $wavelog
          err=10;export err;${errchk}
        fi
    
      done

      rm -f gfs.wind
      rm -f mod_def.ww3
      rm -f ww3_prnc.inp
    else
      echo ' '
      echo " Wind input is not perturbed, single wnd file generated, skipping ${wavemodTAG}"
      echo ' '

    fi

  else

      echo ' '
      echo ' Atmospheric inputs not generated, this run did not request pre-processed winds '
      echo ' '
  
  fi

#-------------------------------------------------------------------
# CURR processing

  if [ "${WW3CURINP}" = 'YES' ]; then

#-------------------------------------------------------------------
# 4.  Process current fields
# 4.a Get into single file 
    if [ "${RUNMEM}" = "-1" ] || [ "${WW3CURIENS}" = "T" ] || [ "$waveMEMB" = "00" ]
    then

      set +x
      echo ' '
      echo '   Concatenate binary current fields ...'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x

      files=`ls rtofs.* 2> /dev/null`

      if [ -z "$files" ]
      then
        msg="ABNORMAL EXIT: NO rtofs.* FILES FOUND"
        postmsg "$jlogfile" "$msg"
        set +x
        echo ' '
        echo '******************************************** '
        echo '*** FATAL ERROR : CANNOT FIND WIND FILES *** '
        echo '******************************************** '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        echo "$wavemodTAG prep $date $cycle : no current files found." >> $wavelog
        err=11;export err;${errchk}
      fi

      rm -f curr.${curID}

      for file in $files
      do
        cat $file >> curr.${curID}
        rm -f $file
      done

    else
      echo ' '
      echo " Current input is not perturbed, single cur file generated, skipping ${wavemodTAG}"
      echo ' '
    fi

  else
  
      echo ' '
      echo ' Current inputs not generated, this run did not request pre-processed currents '
      echo ' '

  fi


# --------------------------------------------------------------------------- #
# 5. Create ww3_multi.inp

# 5.a ww3_multi template

  if [ -f $FIXwave/ww3_multi.${wavemodID}.inp.tmpl ]
  then
    cp $FIXwave/ww3_multi.${wavemodID}.inp.tmpl ww3_multi.inp.tmpl
  fi

  if [ ! -f ww3_multi.inp.tmpl ]
  then
    msg="ABNORMAL EXIT: NO TEMPLATE FOR INPUT FILE"
    postmsg "$jlogfile" "$msg"
    set +x
    echo ' '
    echo '************************************************ '
    echo '*** FATAL ERROR : NO TEMPLATE FOR INPUT FILE *** '
    echo '************************************************ '
    echo ' '
    echo "${wavemodTAG} fcst $date $cycle : ww3_multi file missing." >> $wavelog
    echo $msg
    [[ "$LOUD" = YES ]] && set -x
    err=12;export err;${errchk}
  fi

# 5.b Buoy location file

  if [ -f $FIXwave/wave_$wavemodID.buoys ]
  then
    cp $FIXwave/wave_$wavemodID.buoys buoy.loc
  fi

  if [ -f buoy.loc ]
  then
    set +x
    echo "   buoy.loc copied ($FIXwave/wave_$wavemodID.buoys)."
    [[ "$LOUD" = YES ]] && set -x
  else
    set +x
    echo "   buoy.loc not found.                           **** WARNING **** "
    [[ "$LOUD" = YES ]] && set -x
    postmsg "$jlogfile" " **** WARNING **** buoy.loc NOT FOUND"
    touch buoy.loc
    echo "$wavemodID fcst $date $cycle : no buoy locations file." >> $wavelog
  fi

# Initialize inp file parameters
  NFGRIDS=0
  NMGRIDS=0
  CPLILINE='$'
  ICELINE='$'
  ICEFLAG='no'
  CURRLINE='$'
  CURRFLAG='no'
  WINDLINE='$'
  WINDFLAG='no'
  UNIPOINTS='$'

# Check for required inputs and coupling options
  if [ $buoy ]
  then
    UNIPOINTS="'$buoy'"
  fi

# Check if esmfGRD is set
  if [ ${esmfGRD} ]
  then
    NFGRIDS=`expr $NFGRIDS + 1`
  fi 

  case ${WW3ATMINP} in
    'YES' )
      NFGRIDS=`expr $NFGRIDS + 1`
      WINDLINE="  '$wndID'  F F T F F F F"
      WINDFLAG="$wndID"
    ;;
    'CPL' )
      WINDFLAG="CPL:${esmfGRD}"
      WNDIFLAG='T'
      CPLILINE="  '${esmfGRD}' F F T F F F F"
    ;;
  esac
  
  case ${WW3ICEINP} in
    'YES' ) 
      NFGRIDS=`expr $NFGRIDS + 1`
      ICELINE="  '$iceID'  F F F T F F F"
      ICEFLAG="$iceID"
    ;;
    'CPL' )
      ICEFLAG="CPL:${esmfGRD}"
      ICEIFLAG='T'
      CPLILINE="  '${esmfGRD}' F F ${WNDIFLAG} T F F F"
    ;;
  esac

  case ${WW3CURINP} in
    'YES' ) 
      NFGRIDS=`expr $NFGRIDS + 1`
      CURRLINE="  '$curID'  F T F F F F F"
      CURRFLAG="$curID"
    ;;
    'CPL' )
      CURRFLAG="CPL:${esmfGRD}"
      CURIFLAG='T'
      CPLILINE="  '${esmfGRD}' F T ${WNDIFLAG} ${ICEIFLAG} F F F"
    ;;
  esac

  unset agrid
  agrid=
  gline=
  GRDN=0
#  grdGRP=1 # Single group for now
  for grid in ${waveGRD} 
  do
    GRDN=`expr ${GRDN} + 1`
    agrid=( ${agrid[*]} ${grid} )
    NMGRIDS=`expr $NMGRIDS + 1`
    gridN=`echo $waveGRDN | awk -v i=$GRDN '{print $i}'`
    gridG=`echo $waveGRDG | awk -v i=$GRDN '{print $i}'`
    gline="${gline}'${grid}'  'no' 'CURRFLAG' 'WINDFLAG' 'ICEFLAG'  'no' 'no' 'no'  ${gridN} ${gridG}  0.00 1.00  F\n"
  done
  gline="${gline}\$"
  echo $gline

  sed -e "s/NFGRIDS/$NFGRIDS/g" \
      -e "s/NMGRIDS/${NMGRIDS}/g" \
      -e "s/FUNIPNT/${FUNIPNT}/g" \
      -e "s/PNTSRV/${PNTSRV}/g" \
      -e "s/FPNTPROC/${FPNTPROC}/g" \
      -e "s/FGRDPROC/${FGRDPROC}/g" \
      -e "s/OUTPARS/${OUTPARS}/g" \
      -e "s/CPLILINE/${CPLILINE}/g" \
      -e "s/UNIPOINTS/${UNIPOINTS}/g" \
      -e "s/GRIDLINE/${gline}/g" \
      -e "s/ICELINE/$ICELINE/g" \
      -e "s/CURRLINE/$CURRLINE/g" \
      -e "s/WINDLINE/$WINDLINE/g" \
      -e "s/ICEFLAG/$ICEFLAG/g" \
      -e "s/CURRFLAG/$CURRFLAG/g" \
      -e "s/WINDFLAG/$WINDFLAG/g" \
      -e "s/RUN_BEG/$time_beg/g" \
      -e "s/RUN_END/$time_end/g" \
      -e "s/OUT_BEG/$time_beg/g" \
      -e "s/OUT_END/$time_end/g" \
      -e "s/DTFLD/ $DTFLD/g" \
      -e "s/FIELDS/$FIELDS/g" \
      -e "s/DTPNT/ $DTPNT/g" \
      -e "/BUOY_FILE/r buoy.loc" \
      -e "s/BUOY_FILE/DUMMY/g" \
      -e "s/RST_BEG/$time_rst_ini/g" \
      -e "s/DTRST/$DTRST/g" \
      -e "s/RST_END/$time_rst_end/g" \
                                     ww3_multi.inp.tmpl | \
  sed -n "/DUMMY/!p"               > ww3_multi.inp

  rm -f ww3_multi.inp.tmpl buoy.loc

  if [ -f ww3_multi.inp ]
  then
    echo " Copying file ww3_multi.${wavemodTAG}.inp to $COMOUT "
    cp ww3_multi.inp ${COMOUT}/rundata/ww3_multi.${wavemodTAG}.$cycle.inp
  else
    echo "FATAL ERROR: file ww3_multi.${wavemodTAG}.$cycle.inp NOT CREATED, ABORTING"
    err=13;export err;${errchk}
  fi 

# --------------------------------------------------------------------------- #
# 6.  Output to /com

  if [ "$SENDCOM" = 'YES' ]
  then

   if [ "${WW3ATMINP}" = 'YES' ]; then

    for grdID in $wndID $curvID 
    do
      set +x
      echo ' '
      echo "   Saving wind.$grdID as $COMOUT/rundata/${wavemodTAG}.$grdID.$PDY$cyc.wind"
      echo "   Saving times.$grdID file as $COMOUT/rundata/${wavemodTAG}.$grdID.$PDY$cyc.$grdID.wind.times"
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      cp wind.$grdID $COMOUT/rundata/${wavemodTAG}.$grdID.$PDY$cyc.wind
      cp times.$grdID $COMOUT/rundata/${wavemodTAG}.$grdID.$PDY$cyc.$grdID.wind.times
    done
   fi

   if [ "${WW3CURINP}" = 'YES' ]; then

    for grdID in $curID
    do
      set +x
      echo ' '
      echo "   Saving current.$grdID as $COMOUT/rundata/${wavemodTAG}.$grdID.$PDY$cyc.curr"
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      cp curr.$grdID $COMOUT/rundata/${wavemodTAG}.$grdID.$PDY$cyc.curr
    done
   fi
  fi 

  rm -f wind.*
  rm -f $iceID.*
  rm -f times.*

# --------------------------------------------------------------------------- #
# 7.  Ending output

  set +x
  echo ' '
  echo "Ending at : `date`"
  echo ' '
  echo '                     *** End of MWW3 preprocessor ***'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  msg="$job completed normally"
  postmsg "$jlogfile" "$msg"

# End of MWW3 preprocessor script ------------------------------------------- #
