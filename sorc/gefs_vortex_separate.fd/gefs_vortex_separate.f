C$$$  MAIN PROGRAM DOCUMENTATION BLOCK
C
C MAIN PROGRAM: GEFS_VORTEX_SEPARATE
C   PROGMMR: Richard Wobus    ORG: NP22       DATE: 2005-07-12
C
C ABSTRACT: RELOCATES HURRICANE VORTEX IN GLOBAL MODEL.
C   THIS PROGRAM CONTAINS THE FOLLOWING STEPS:
C   1) CONVERTS THE GLOBAL SPECTRAL COEFS TO GAUSSIAN GRID
C      AND DEFINES A 40x40 DEG AREAS AROUND THE REPORTED HURRICANES.
C   2) USING GFDL PROCEDURE SEPARATES THE HURRICANE DISTURBANCE FROM
C      THE ENVIRONMENTAL FIELD AND MOVE THE HURRICANE DISTURBANCE TO
C      THE OBSERVATIONAL LOCATION.
C   3) CONVERTS THE GAUSSIAN GRID TO GLOBAL SPECTRAL COEFS.
C THIS VERSION SEPARATES THE VORTEX ONLY.  THE VORTEX IS INSERTED
C IN THE NEW POSITION BY THE PROGRAM GEFS_VORTEX_COMBINE
C
C PROGRAM HISTORY LOG:
C 2000-04-25  QINGFU LIU
C 2000-06-14  DENNIS KEYSER -- ADDED CALLS TO W3TAGB AND W3TAGE
C        AND CALLS TO ERREXIT FOR NON-ZERO STOP CONDITIONS.
C 2005-04-14  QINGFU LIU    -- NEW VERSION FOR ENSEMBLE,
C                              SEPARATES THE VORTEX ONLY
C 2005-07-13  RICHARD WOBUS -- RENAME AND UPDATE DOCBLOCK
C 2005-10-03  RICHARD WOBUS -- RENAME AND UPDATE FOR MORE MEMBERS
C
C USAGE:
C   INPUT FILES:
C
C     UNIT 11    THE CURRENT TC VITAL FILE
C     UNIT 20    THE SIGMA FILE AT TIME t-3
C     UNIT 21    THE SIGMA FILE AT (CURRENT) TIME t
C     UNIT 22    THE SIGMA FILE AT TIME t+3
C     UNIT 30    MODEL VORTEX CENTER LOCATION AT TIME t-3,t,t+3
C
C   SUBPROGRAMS CALLED:
C     UNIQUE     - modules     BOUND_QLIU  fft99      sig_p_convt1
C                  SEPAR_QLIU  WNLIT       FDUMP      H12
C                  I1MACH      J4SAVE      XGETUA     WNLSM
C                  WNNLS       XERABT      XERCTL     XERPRT
C                  XERROR      XERRWV      XERSAV     srotm
C                  srotmg      rodist_qliu amatrix_qliu
C     LIBRARY:
C       W3LIB    - W3TAGB      W3TAGE      ERREXIT
C
C
C   EXIT STATES:
C     COND =  0 - SUCCESSFUL RUN
C     COND = 56 - NO TC VITAL DATA (OR TC VITAL IS EMPTY)
C
C REMARKS: NONE.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C   MACHINE:  IBM-SP
C
C$$$
C
C234567890123456789012345678901234567890123456789012345678901234567890
C

      PROGRAM GEFS_VORTEX_SEPARATE

      use sigio_module
      use sigio_r_module

      type(sigio_head) heado
      type(sigio_data) datao

      PARAMETER (IRX=41, JRX=41, NST=10 )

      COMMON/SMTH/ CLAT,CLON
      COMMON/CNT/ SLON,SLAT
      COMMON /NHC/ KSTM,IC_N(NST),JC_N(NST)
      COMMON /NHC1/SLON_N(NST),SLAT_N(NST),CLON_N(NST),CLAT_N(NST)

      COMMON /HDAT1/NWRT1,NRED1,NWT1
      COMMON /HDAT3/NWRT2,NRED2
C                                 ! NST is the max storm num
      CHARACTER ST_NAME(NST)*3,TCVT(NST)*95
      COMMON /STNAME/ST_NAME
      COMMON /TCVIT/TCVT
      COMMON /CHEN/KUNIT,ITIM

      CHARACTER ENS_MEM*4

      COMMON /ENS1/ENS_MEM,idatez,IUTCZ,icycx

      REAL,   ALLOCATABLE :: GLAT(:),GLON(:)
      REAL,   ALLOCATABLE :: COLRAD(:),WGT(:),WGTCS(:),RCS2(:)

      REAL,   ALLOCATABLE :: ZG(:,:),PSFC(:,:),PSLB(:,:)

      REAL,   ALLOCATABLE :: HDAT(:,:,:,:),HDATA(:,:,:),PDAT(:,:,:)

      REAL(4),ALLOCATABLE :: WORK_4(:,:)
      REAL,   ALLOCATABLE :: WORK_8(:)
      REAL,   ALLOCATABLE :: WK_S1(:,:),WK_S2(:,:),WK_G(:,:,:),
     1                       WK_G2(:,:,:),WK_G3(:,:,:),WK_G4(:,:,:)

      REAL(4),ALLOCATABLE :: SLREF(:),VCRD(:,:)

      real,   allocatable :: srlsphc(:)
      real,   allocatable :: srlsphcl(:,:)

      real,   allocatable :: srlpd(:,:)
      real,   allocatable :: srlpi(:,:)
      real,   allocatable :: srlpo(:,:)
      real,   allocatable :: srlhd(:,:)
      real,   allocatable :: srlhi(:,:)
      real,   allocatable :: srlho(:,:)
      real,   allocatable :: srltd(:,:,:)
      real,   allocatable :: srlti(:,:,:)
      real,   allocatable :: srlto(:,:,:)
      real,   allocatable :: srldd(:,:,:)
      real,   allocatable :: srldi(:,:,:)
      real,   allocatable :: srldo(:,:,:)
      real,   allocatable :: srlzd(:,:,:)
      real,   allocatable :: srlzi(:,:,:)
      real,   allocatable :: srlzo(:,:,:)
      real,   allocatable :: srlqd(:,:,:)
      real,   allocatable :: srlqi(:,:,:)
      real,   allocatable :: srlqo(:,:,:)

      INTEGER IDVC,IDSL

      REAL(4) PSREF(1)

      REAL(4) FHOUR
!      REAL(4) FHOUR,DUMMY(245)
     
      CHARACTER*3 MEMBER 
!      CHARACTER*8 LAB(4)
      DIMENSION IDATE(4)

      CHARACTER cfile*7,kfile*7

!      COMMON /COEF1/LAB
      COMMON /COEF2/IDATE
!      COMMON /COEF3/FHOUR,DUMMY
      COMMON /COEF5/NCNT,NCNT2

      CALL W3TAGB('GEFS_VORTEX_SEPARATE',2000,0202,0068,'NP22')
C
      READ(5,*)ITIM,MEMBER

      NSEM=1
      IF(trim(MEMBER).EQ.'n1')NSEM=3
      IF(trim(MEMBER).EQ.'p1')NSEM=4
      IF(trim(MEMBER).EQ.'n2')NSEM=5
      IF(trim(MEMBER).EQ.'p2')NSEM=6
      IF(trim(MEMBER).EQ.'n3')NSEM=7
      IF(trim(MEMBER).EQ.'p3')NSEM=8
      IF(trim(MEMBER).EQ.'n4')NSEM=9
      IF(trim(MEMBER).EQ.'p4')NSEM=10
      IF(trim(MEMBER).EQ.'n5')NSEM=11
      IF(trim(MEMBER).EQ.'p5')NSEM=12
      IF(trim(MEMBER).EQ.'n01')NSEM=3
      IF(trim(MEMBER).EQ.'p01')NSEM=4
      IF(trim(MEMBER).EQ.'n02')NSEM=5
      IF(trim(MEMBER).EQ.'p02')NSEM=6
      IF(trim(MEMBER).EQ.'n03')NSEM=7
      IF(trim(MEMBER).EQ.'p03')NSEM=8
      IF(trim(MEMBER).EQ.'n04')NSEM=9
      IF(trim(MEMBER).EQ.'p04')NSEM=10
      IF(trim(MEMBER).EQ.'n05')NSEM=11
      IF(trim(MEMBER).EQ.'p05')NSEM=12
      IF(trim(MEMBER).EQ.'n06')NSEM=13
      IF(trim(MEMBER).EQ.'p06')NSEM=14
      IF(trim(MEMBER).EQ.'n07')NSEM=15
      IF(trim(MEMBER).EQ.'p07')NSEM=16
      IF(trim(MEMBER).EQ.'n08')NSEM=17
      IF(trim(MEMBER).EQ.'p08')NSEM=18
      IF(trim(MEMBER).EQ.'n09')NSEM=19
      IF(trim(MEMBER).EQ.'p09')NSEM=20
      IF(trim(MEMBER).EQ.'n10')NSEM=21
      IF(trim(MEMBER).EQ.'p10')NSEM=22
      IF(trim(MEMBER).EQ.'n11')NSEM=23
      IF(trim(MEMBER).EQ.'p11')NSEM=24
      IF(trim(MEMBER).EQ.'n12')NSEM=25
      IF(trim(MEMBER).EQ.'p12')NSEM=26
      IF(trim(MEMBER).EQ.'n13')NSEM=27
      IF(trim(MEMBER).EQ.'p13')NSEM=28
      IF(trim(MEMBER).EQ.'n14')NSEM=29
      IF(trim(MEMBER).EQ.'p14')NSEM=30
      IF(trim(MEMBER).EQ.'n15')NSEM=31
      IF(trim(MEMBER).EQ.'p15')NSEM=32
      IF(trim(MEMBER).EQ.'n16')NSEM=33
      IF(trim(MEMBER).EQ.'p16')NSEM=34
      IF(trim(MEMBER).EQ.'n17')NSEM=35
      IF(trim(MEMBER).EQ.'p17')NSEM=36
      IF(trim(MEMBER).EQ.'n18')NSEM=37
      IF(trim(MEMBER).EQ.'p18')NSEM=38
      IF(trim(MEMBER).EQ.'n19')NSEM=39
      IF(trim(MEMBER).EQ.'p19')NSEM=40
      IF(trim(MEMBER).EQ.'n20')NSEM=41
      IF(trim(MEMBER).EQ.'p20')NSEM=42

C
!      IUNIT = 20+NSEM
!      KUNIT = 50+NSEM
      IF(NSEM.EQ.1)THEN
        IUNIT = 21
        KUNIT = 51
        cfile='fort.21'
        kfile='fort.51'
      ELSE
        IUNIT = 24
        KUNIT = 54
        cfile='fort.24'
        kfile='fort.54'
      END IF
C
      PRINT*,'IUNIT,KUNIT,NSEM= ',IUNIT,KUNIT,NSEM 
c
      NRED1 = 0
      NWRT1 = 0
      NRED2 = 0
      NWRT2 = 0
       NCNT = 0
C
!      READ(IUNIT) LAB
c      WRITE(10) LAB
23    format(4A8)
C
!      READ(IUNIT) FHOUR,(IDATE(I),I=1,4),DUMMY

c      call sigio_sropen(IUNIT,cfile,iret)
c      call sigio_srhead(IUNIT,heado,iret)

c      call sigio_swopen(KUNIT,kfile,iret)
c      call sigio_swhead(KUNIT,heado,iret)

       call sigio_srohdc(iunit,cfile,heado,datao,iret)
       if (iret .ne. 0) then
	 print *,'sigio_srohdc failed',iunit,cfile,iret,'=iret'
       endif

       idvc = heado%idvc  !idvc=2 for hybrid, idvc=1 for sigma files
       idsl = heado%idsl

       MWAVE=heado%jcap
       KMAX=heado%levs
       ITRAC=heado%ntrac

!      MWAVE=DUMMY(202)
!      KMAX=DUMMY(203)
!      IF(MWAVE.LE.250)THEN
!        IMAX=384
!        JMAX=190
!      ELSE
!        IMAX=512
!        JMAX=256
!      END IF
c      IMAX=DUMMY(208)
c      JMAX=DUMMY(209)
!      ITRAC=DUMMY(214)
      IKMAX=(ITRAC-2)*KMAX

      imax=heado%lonb
      jmax=heado%latb

      IDATE=heado%idate
      FHOUR=heado%fhour

      print*,'MWAVE,KMAX=',MWAVE,KMAX

      WRITE(6,210) (IDATE(I),I=1,4),FHOUR
c     1    ,(DUMMY(K),K=1,2*KMAX+1)
210   FORMAT(5X,' INPUT DATE AND FCST HOUR ',4I5,F7.1/(2X,G13.6))

      MAXWV=(MWAVE+1)*(MWAVE+2)/2
      MAXWV2=2*MAXWV
      MAXWV22=MAXWV2+1
   
      JHF=JMAX/2

      MTV=KMAX*4+2
      MTV1=KMAX*5+2
      MTV2=KMAX*6+3
      MTV3=(2*KMAX+1)*6+3     

      ALLOCATE ( GLAT(JMAX),GLON(IMAX) ) 
      ALLOCATE ( COLRAD(JHF), WGT(JHF),WGTCS(JHF),RCS2(JHF) ) 
      ALLOCATE ( ZG(IMAX,JMAX),PSFC(IMAX,JMAX),PSLB(IMAX,JMAX) )
      ALLOCATE ( WORK_4(MAXWV2,MTV1+IKMAX) )
      ALLOCATE ( WORK_8(MAXWV22) )
      ALLOCATE ( WK_S1(MAXWV2,KMAX),WK_S2(MAXWV2,KMAX) )
      ALLOCATE ( WK_G(IMAX,JMAX,KMAX),WK_G2(IMAX,JMAX,KMAX) )
      ALLOCATE ( WK_G3(IMAX,JMAX,KMAX),WK_G4(IMAX,JMAX,KMAX) )
      ALLOCATE ( SLREF(KMAX) )

      ALLOCATE ( HDAT(IRX,JRX,MTV2,NST) )
      ALLOCATE ( HDATA(IMAX,JMAX,MTV) )
      ALLOCATE ( PDAT(IRX,JRX,MTV3) )

      allocate (srlsphc(maxwv2))
      allocate (srlsphcl(maxwv2,kmax))

      allocate (srlhd(imax,jmax))
      allocate (srlhi(imax,jmax))
      allocate (srlho(imax,jmax))
      allocate (srlpd(imax,jmax))
      allocate (srlpi(imax,jmax))
      allocate (srlpo(imax,jmax))
      allocate (srltd(imax,jmax,kmax))
      allocate (srlti(imax,jmax,kmax))
      allocate (srlto(imax,jmax,kmax))
      allocate (srldd(imax,jmax,kmax))
      allocate (srldi(imax,jmax,kmax))
      allocate (srldo(imax,jmax,kmax))
      allocate (srlzd(imax,jmax,kmax))
      allocate (srlzi(imax,jmax,kmax))
      allocate (srlzo(imax,jmax,kmax))
      allocate (srlqd(imax,jmax,kmax))
      allocate (srlqi(imax,jmax,kmax))
      allocate (srlqo(imax,jmax,kmax))

           print *,"   after allocate"


           ijmax=imax*jmax
           ijkmax=ijmax*kmax

c           print *
           do nw=1,maxwv2
             srlsphc(nw)=datao%hs(nw)
           enddo
           call sptez(0,mwave,4,imax,jmax,srlsphc,srlhi,1)
c           call srangel (srlhi ,ijmax,' hs in  ',0)
c           print *

           do nw=1,maxwv2
             srlsphc(nw)=datao%ps(nw)
           enddo
           call sptez(0,mwave,4,imax,jmax,srlsphc,srlpi,1)
c           Call srangel (srlpi ,ijmax,' ps in  ',0)
c           print *

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%t(nw,k)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srlti,1)
c           Call srangel (srlti  ,ijkmax,' t in  ',0)
c          do k=1,kmax
c           call srangel (srlti(1,1,k),ijmax,' t in  ',k)
c          enddo
c           print *

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%d(nw,k)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srldi,1)
c           call srangel (srldi  ,ijkmax,' d in  ',0)
c          do k=1,kmax
c           call srangel (srldi(1,1,k),ijmax,' d in  ',k)
c          enddo
c           print *

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%z(nw,k)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srlzi,1)
c           call srangel (srlzi  ,ijkmax,' z in  ',0)
c          do k=1,kmax
c           call srangel (srlzi(1,1,k),ijmax,' z in  ',k)
c          enddo
c           print *

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%q(nw,k,1)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srlqi,1)
c           call srangel (srlqi  ,ijkmax,' q in  ',0)
c          do k=1,kmax
c           call srangel (srlqi(1,1,k),ijmax,' q in  ',k)
c          enddo
c           print *

      CALL GLATS(JHF,COLRAD,WGT,WGTCS,RCS2)

      PI=ASIN(1.)*2
      RDR=180./PI
C
      DO LL = 1,JHF
      LLS = JMAX+1 - LL
      GLAT(LL)  = 90. - COLRAD(LL)*RDR
      GLAT(LLS) = -GLAT(LL)
      ENDDO
C
      DLN = 360.0/FLOAT(IMAX)
      DO LN = 1,IMAX
      GLON(LN) = (LN-1) * DLN
      ENDDO

      nvcd=heado%nvcoord
      allocate ( vcrd(KMAX+1,nvcd) )
      vcrd=heado%vcoord
    
      PSREF=1.E5

      CALL sigio_modpr(1,1,KMAX,nvcd,idvc,idsl,vcrd,iret,
     &                 ps=PSREF,pm=SLREF)

      SLREF=SLREF/1.E5

      CALL HURR_MESS(NSEM,IMAX,JMAX,GLON,GLAT)

cc
      NCNT = NCNT + 1 
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2)

      DO NW=1,MAXWV2
	work_4(nw,ncnt)=datao%hs(nw)
        WORK_8(NW) = WORK_4(NW,NCNT)
      END DO

      call SPTEZ(0,MWAVE,4,IMAX,JMAX,WORK_8,WK_G(1,1,1),+1)

      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G(1,1,1),1)

c      WRITE(10) (WORK_4(NW,NCNT),NW=1,MAXWV2)
C
C     READ(IUNIT) ( Q(NW),NW=1,MAXWV2)
      NCNT = NCNT + 1
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2)

      DO NW=1,MAXWV2
	work_4(nw,ncnt) = datao%ps(nw)
        WORK_8(NW) = WORK_4(NW,NCNT)
      END DO

      call SPTEZ(0,MWAVE,4,IMAX,JMAX,WORK_8,WK_G(1,1,1),+1)
      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G(1,1,1),2)
C
      DO 220 K=1,KMAX
C     READ(IUNIT) (TE(NW),NW=1,MAXWV2)
      NCNT = NCNT + 1
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2)

      DO NW=1,MAXWV2
	work_4(nw,ncnt) = datao%t(nw,k)
        WK_S1(NW,K) = WORK_4(NW,NCNT)
      END DO
220   CONTINUE

      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S1,WK_G,+1)

      DO 222 K=1,KMAX
      IDX=10
      IF(K.EQ.1)IDX=3
      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G(1,1,K),IDX)
222   CONTINUE
C
      DO 230 K=1,KMAX
      NCNT = NCNT + 1
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2)

      DO NW=1,MAXWV2
	work_4(nw,ncnt) = datao%d(nw,k)
        WK_S1(NW,K) = WORK_4(NW,NCNT)
      END DO

      NCNT = NCNT + 1
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2)

      DO NW=1,MAXWV2
	work_4(nw,ncnt) = datao%z(nw,k)
        WK_S2(NW,K) = WORK_4(NW,NCNT)
      END DO

230   CONTINUE

      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S1,WK_G,+1) 
      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S2,WK_G2,+1) 
      CALL SPTEZMV(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S1,WK_S2,
     &             WK_G3,WK_G4,+1)      

      IDX=10
      DO 232 K=1,KMAX
      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G(1,1,K),IDX)
      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G2(1,1,K),IDX)
C
C.. CONVERT DI, ZE TO U,V and U,V TO DI ZE again for confirm
C
      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G3(1,1,K),100)
      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G4(1,1,K),101)
232   CONTINUE
C
      DO 240 K=1,KMAX
C     READ(IUNIT) (RQ(NW),NW=1,MAXWV2)
      NCNT = NCNT + 1
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2) 
      DO NW=1,MAXWV2
	work_4(nw,ncnt) = datao%q(nw,k,1)
        WK_S1(NW,K) = WORK_4(NW,NCNT)
      END DO
240   CONTINUE

      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S1,WK_G,+1)
 
      IDX = 10
      DO 242 K=1,KMAX
      CALL SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1         MTV,MTV2,HDAT,HDATA,WK_G(1,1,K),IDX)
242   CONTINUE
C
      IDX = 10
      DO 270 K=1,KMAX
      NCNT = NCNT + 1
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2)
       do nw=1,maxwv2
	 work_4(nw,ncnt)=datao%q(nw,k,2)
       enddo
c      WRITE(10) (WORK_4(NW,NCNT),NW=1,MAXWV2)
270   CONTINUE
c
      DO 280 K=1,IKMAX
      NCNT = NCNT + 1
!      READ(IUNIT) (WORK_4(NW,NCNT),NW=1,MAXWV2)
       do nw=1,maxwv2
	 work_4(nw,ncnt)=datao%q(nw,k,3)
       enddo
c      WRITE(10) (WORK_4(NW,NCNT),NW=1,MAXWV2)
280   CONTINUE

      print*,'NCNT=',NCNT
c      print*,'NCNT should equal to 170 or'212+IKMAX
c      if(NCNT.ne.(212+IKMAX))print*,'Wrong Data Read In'

      DEALLOCATE ( COLRAD, WGT, WGTCS, RCS2 )
      DEALLOCATE ( ZG, PSFC )
      DEALLOCATE ( WORK_8, WK_S1, WK_S2, WK_G )
      DEALLOCATE ( WK_G2, WK_G3, WK_G4 )

      CALL HURR_REL(NSEM,MWAVE,IMAX,JMAX,KMAX,IKMAX,MAXWV2,
     1                 JHF,MTV,MTV1,MTV2,MTV3,
     2                 HDAT,HDATA,PDAT,WORK_4,PSLB,SLREF,
     3                 nvcd,idvc,idsl,vcrd,datao) 

c      CALL HURR_REL(MWAVE,KMAX,MAXWV2,
c     1                 MTV,MTV1,MTV2,MTV3,
c     2                 HDAT,HDATA,PDAT,WORK_4,PSLB)


      DO K=1,KMAX
        datao%d(1,K)=0.
        datao%z(1,K)=0.
      END DO

           print *,"   after zero z and d"

           do nw=1,maxwv2
             srlsphc(nw)=datao%hs(nw)
           enddo
           call sptez(0,mwave,4,imax,jmax,srlsphc,srlho,1)

           do nw=1,maxwv2
             srlsphc(nw)=datao%ps(nw)
           enddo
           call sptez(0,mwave,4,imax,jmax,srlsphc,srlpo,1)

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%t(nw,k)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srlto,1)

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%d(nw,k)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srldo,1)

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%z(nw,k)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srlzo,1)

          do k=1,kmax
           do nw=1,maxwv2
             srlsphcl(nw,k)=datao%q(nw,k,1)
           enddo
          enddo
           call sptezm(0,mwave,4,imax,jmax,kmax,srlsphcl,srlqo,1)

           do j=1,jmax
             do i=1,imax
               srlhd(i,j)=srlho(i,j)-srlhi(i,j)
               srlpd(i,j)=srlpo(i,j)-srlpi(i,j)
             enddo
           enddo

           do k=1,kmax
             do j=1,jmax
               do i=1,imax
                 srltd(i,j,k)=srlto(i,j,k)-srlti(i,j,k)
                 srldd(i,j,k)=srldo(i,j,k)-srldi(i,j,k)
                 srlzd(i,j,k)=srlzo(i,j,k)-srlzi(i,j,k)
                 srlqd(i,j,k)=srlqo(i,j,k)-srlqi(i,j,k)
               enddo
             enddo
           enddo

           print *

           call srangel (srlhi,ijmax,'hs in   ',0)
           call srangel (srlhd,ijmax,'hs diff ',0)
           call srangel (srlho,ijmax,'hs out  ',0)
           print *

           call srangel (srlpi,ijmax,'ps in   ',0)
           call srangel (srlpd,ijmax,'ps diff ',0)
           call srangel (srlpo,ijmax,'ps out  ',0)
           print *

           call srangel (srlti,ijkmax,'t in   ',0)
           call srangel (srltd,ijkmax,'t diff ',0)
           call srangel (srlto,ijkmax,'t out  ',0)
          do k=1,kmax
           print *
           call srangel (srlti(1,1,k),ijmax,'t in   ',k)
           call srangel (srltd(1,1,k),ijmax,'t diff ',k)
           call srangel (srlto(1,1,k),ijmax,'t out  ',k)
          enddo
           print *

           call srangel (srldi,ijkmax,'d in   ',0)
           call srangel (srldd,ijkmax,'d diff ',0)
           call srangel (srldo,ijkmax,'d out  ',0)
          do k=1,kmax
           print *
           call srangel (srldi(1,1,k),ijmax,'d in   ',k)
           call srangel (srldd(1,1,k),ijmax,'d diff ',k)
           call srangel (srldo(1,1,k),ijmax,'d out  ',k)
          enddo
           print *

           call srangel (srlzi,ijkmax,'z in   ',0)
           call srangel (srlzd,ijkmax,'z diff ',0)
           call srangel (srlzo,ijkmax,'z out  ',0)
          do k=1,kmax
           print *
           call srangel (srlzi(1,1,k),ijmax,'z in   ',k)
           call srangel (srlzd(1,1,k),ijmax,'z diff ',k)
           call srangel (srlzo(1,1,k),ijmax,'z out  ',k)
          enddo
           print *

           call srangel (srlqi,ijkmax,'q in   ',0)
           call srangel (srlqd,ijkmax,'q diff ',0)
           call srangel (srlqo,ijkmax,'q out  ',0)
          do k=1,kmax
           print *
           call srangel (srlqi(1,1,k),ijmax,'q in   ',k)
           call srangel (srlqd(1,1,k),ijmax,'q diff ',k)
           call srangel (srlqo(1,1,k),ijmax,'q out  ',k)
          enddo
           print *

      call  sigio_swohdc(kunit,kfile,heado,datao,iret)
       if (iret .ne. 0) then
	 print *,'sigio_swohdc failed',kunit,kfile,iret,'=iret'
       endif

      CALL W3TAGE('GEFS_VORTEX_SEPARATE')
C
      STOP
      END
C
      SUBROUTINE GLATS(LGGHAF,COLRAD,WGT,WGTCS,RCS2)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    GLATS       COMPUTES LOCATION OF GAUSSIAN LATITUDES.
C   PRGMMR: JOSEPH SELA      ORG: W/NMC23    DATE: 88-04-05
C
C ABSTRACT: COMPUTES THE LOCATION OF THE GAUSSIAN LATITUDES FOR THE
C   INPUT LGGHAF.  THE LATITUDES ARE DETERMINED BY FINDING
C   THE ZEROS OF THE LEGENDRE POLYNOMIALS.
C
C PROGRAM HISTORY LOG:
C   88-04-05  JOSEPH SELA
C
C USAGE:    CALL GLATS (LGGHAF, COLRAD, WGT, WGTCS, RCS2)
C   INPUT ARGUMENT LIST:
C     LGGHAF   - NUMBER OF GAUSSIAN LATITUDES IN A HEMISPHERE.
C
C   OUTPUT ARGUMENT LIST:
C     COLRAD   - ARRAY OF COLATITUDE OF GAUSSIAN LATITUDES
C                IN NORTHERN HEMISPHERE.
C     WGT      - ARRAY OF WEIGHTS AT EACH GAUSSIAN LATITUDE
C                REQUIRED FOR GAUSSIAN QUADRATURE.
C     WGTCS    - ARRAY OF GAUSSIAN WEIGHT/SIN OF COLATITUDE SQUARED.
C     RCS2     - ARRAY OF RECIPROCAL  OF  SIN OF COLATITUDE SQUARED.
C
C   OUTPUT FILES:
C     OUTPUT   - PRINTOUT FILE.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 200.
C   MACHINE:  CYBER 205.
C
C$$$
CCCC  HALF PRECISION COLRAD,WGT,WGTCS,RCS2
      REAL COLRAD(LGGHAF),WGT(LGGHAF),WGTCS(LGGHAF)
      REAL RCS2(LGGHAF)
      EPS=1.E-12
C     PRINT 101
C101  FORMAT ('0 I   COLAT   COLRAD     WGT', 12X, 'WGTCS',
CCCC 1 10X, 'ITER  RES')
      SI = 1.0
      L2=2*LGGHAF
      RL2=L2
      SCALE = 2.0/(RL2*RL2)
      K1=L2-1
      PI = ATAN(SI)*4.E+00
      DRADZ = PI / 360.
      RAD = 0.0
      DO 1000 K=1,LGGHAF
      ITER=0
      DRAD=DRADZ
1     CALL POLY(L2,RAD,P2)
2     P1 =P2
      ITER=ITER+1
      RAD=RAD+DRAD
      CALL POLY(L2,RAD,P2)
      IF(SIGN(SI,P1).EQ.SIGN(SI,P2)) GO TO 2
      IF(DRAD.LT.EPS)GO TO 3
      RAD=RAD-DRAD
      DRAD = DRAD * 0.25
      GO TO 1
3     CONTINUE
      COLRAD(K)=RAD
      PHI = RAD * 180 / PI
      CALL POLY(K1,RAD,P1)
      X = COS(RAD)
      W = SCALE * (1.0 - X*X)/ (P1*P1)
      WGT(K) = W
      SN = SIN(RAD)
      W=W/(SN*SN)
      WGTCS(K) = W
      RC=1./(SN*SN)
      RCS2(K) = RC
      CALL POLY(L2,RAD,P1)
C     PRINT 102,K,PHI,COLRAD(K),WGT(K),WGTCS(K),ITER,P1
C102  FORMAT(1H ,I2,2X,F6.2,2X,F10.7,2X,E13.7,2X,E13.7,2X,I4,2X,D13.7)
1000  CONTINUE
      RETURN
      END
      SUBROUTINE POLY(N,RAD,P)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    POLY        EVALUATES LEGENDRE POLYNOMIAL.
C   PRGMMR: JOSEPH SELA      ORG: W/NMC23    DATE: 88-04-01
C
C ABSTRACT: EVALUATES THE UNNORMALIZED LEGENDRE POLYNOMIAL
C   OF SPECIFIED DEGREE AT A GIVEN COLATITUDE USING A STANDARD
C   RECURSION FORMULA.  REAL ARITHMETIC IS USED.
C
C PROGRAM HISTORY LOG:
C   88-04-01  JOSEPH SELA
C
C USAGE:    CALL POLY (N, RAD, P)
C   INPUT ARGUMENT LIST:
C     N        - DEGREE OF LEGENDRE POLYNOMIAL.
C     RAD      - REAL COLATITUDE IN RADIANS.
C
C   OUTPUT ARGUMENT LIST:
C     P        - REAL VALUE OF LEGENDRE POLYNOMIAL.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 200.
C   MACHINE:  CYBER 205.
C
C$$$
      X = COS(RAD)
      Y1 = 1.0
      Y2=X
      DO 1 I=2,N
      G=X*Y2
      Y3=G-Y1+G-(G-Y1)/FLOAT(I)
      Y1=Y2
      Y2=Y3
1     CONTINUE
      P=Y3
      RETURN
      END


      subroutine maxmin(a,len,k,k1,k2,ch)
      dimension a(len,k)
      character ch*(*)
c
cccc cmic$ do all
cccc cmic$1 shared(a,ch,len,k1,k2)
cccc cmic$1 private(aamax,aamin,m)
      do 100 j=k1,k2
      aamax = a(1,j)
      aamin = a(1,j)
      do 10 m=1,len
      aamax = max( aamax, a(m,j) )
      aamin = min( aamin, a(m,j) )
10    continue
C      print   *,ch,' has max=',aamax,' min=',aamin
100   continue
      return
      end
C
      SUBROUTINE PMSL2PS(IMAX,JMAX,GLON,GLAT,
     1               IUT,MTV2,DUMM,HDAT,ZN,TN)
C
      PARAMETER (IRX=41,JRX=41,NST=10)
      REAL GLON(IMAX),GLAT(JMAX),DUMM(IMAX,JMAX)
      REAL TN(IRX,JRX)
      REAL ZN(IRX,JRX),PSN(IRX,JRX),PSFCN(IRX,JRX)

C
      COMMON /HDAT1/NWRT1,NRED1,NWT1
      REAL HDAT(IRX,JRX,MTV2,NST)

      G = 9.8
      R = 287.05
      GAMMA = 6.7*0.001
C
      CALL CUT_DM(IMAX,JMAX,GLON,GLAT,PSN,DUMM,1)
C
C.. Using interpolated MSLP, Make surface pressure
C
c!OMP PARALLEL DO DEFAULT (SHARED)
c!OMP+ PRIVATE (I,J,TID)

      DO I=1,IRX
      DO J=1,JRX
      PSN(I,J) = ALOG(PSN(I,J))
      ENDDO
      ENDDO
c      TID = OMP_GET_THREAD_NUM()
c      IF (TID .EQ. 0) THEN
c        NTHREADS = OMP_GET_NUM_THREADS()
c        PRINT *, 'Number of threads =', NTHREADS
c      END IF
c      PRINT *, 'Thread',TID,' starting...'
c!OMP END PARALLEL DO
C
C
      DO I=1,IRX 
      DO J=1,JRX
      A = (GAMMA * ZN(I,J)) / TN(I,J)
      B = ALOG(1+A)
      C = (G*B)/(R*GAMMA)
      DD = PSN(I,J) - C
      D1 = EXP(DD)/1000.
C      IF (D1.LE.10.) PRINT*,'SP is Less than 100mb at ',I,J,D1
      PSFCN(I,J) = ALOG(D1)
      ENDDO
      ENDDO
C
      DO I=1,IRX
      DO J=1,JRX
c      DUM1(I,J) = EXP(PSFCN(I,J)) * 1000.
      PSN(I,J) = EXP(PSN(I,J))
      ENDDO 
      ENDDO 
C      print *,'MSLP at Hurricane center ',psn(31,21)/100.

c      call maxmin(psn,41*41,1,1,1,'sea-level pressure in reg')
c      call maxmin(psfcn,41*41,1,1,1,'sfc pressure in reg (hPa)')
c      call maxmin(dum1,41*41,1,1,1,'sfc pressure in reg(ln(cb))')
c      call maxmin(zn,41*41,1,1,1,'terraine in reg')
c      call maxmin(tn,41*41,1,1,1,'temperature at k=1 in reg')
c      print *,'============================'
C
c      print *,'write sfc press'
c      WRITE(IUT) ((PSFCN(I,J),I=1,IRX),J=JRX,1,-1)
      CALL WRIT1(IUT,NWT1,NWRT1,MTV2,PSFCN,HDAT)
c      print *,'write MSLP'
c      WRITE(IUT) ((PSN(I,J),I=1,IRX),J=JRX,1,-1)
      CALL WRIT1(IUT,NWT1,NWRT1,MTV2,PSN,HDAT)
c      print *,'write t1'
c      WRITE(IUT) ((TN(I,J),I=1,IRX),J=JRX,1,-1)
      CALL WRIT1(IUT,NWT1,NWRT1,MTV2,TN,HDAT)
      RETURN
      END
C
      SUBROUTINE SPC2G(IMAX,JMAX,GLON,GLAT,ZG,PSFC,PSLB,
     1               MTV,MTV2,HDAT,HDATA,DUM,IDX)
CCCCC MEMBER HALF
c      SAVE
C
      PARAMETER ( IRX= 41,JRX= 41, NST=10 )

      COMMON/SMTH/ CLAT,CLON
      REAL GLON(IMAX),GLAT(JMAX)
      COMMON /NHC/ KSTM,IC_N(NST),JC_N(NST)
      COMMON /NHC1/ SLON_N(NST),SLAT_N(NST),CLON_N(NST),CLAT_N(NST)
      COMMON/CNT/ SLON,SLAT
      COMMON /CHEN/KUNIT,ITIM
C
      REAL HDAT(IRX,JRX,MTV2,NST),HDATA(IMAX,JMAX,MTV)
      REAL DUM(IMAX,JMAX)

      COMMON /HDAT1/NWRT1,NRED1,NWT1
      COMMON /HDAT3/NWRT2,NRED2

       REAL ZG(IMAX,JMAX),PSFC(IMAX,JMAX),PSLB(IMAX,JMAX)
       REAL T1(IMAX,JMAX)
       REAL PS(IMAX,JMAX),DUMM(IMAX,JMAX),PSL(IMAX,JMAX)

      REAL ZN(IRX,JRX),TN(IRX,JRX),NEW(IRX,JRX)
C
C.. Global coefficent to Gaussian grid
C
c      call SPTEZ(0,MWAVE,4,IMAX,JMAX,DO,DUM,+1)

      IF(IDX.NE.100.AND.IDX.NE.101) THEN
c       WRITE(66) DUM

       NWRT2=NWRT2+1
c       PRINT*,'WRIT2 COUNT = ',NWRT2
       DO J=1,JMAX
       DO I=1,IMAX
         HDATA(I,J,NWRT2)=DUM(I,J)
       END DO
       END DO

c       CALL WRIT2(DUM)
c       print *,'=====IDX ',IDX
c       call maxmin(DUM,IMAX*JMAX,1,1,1,'DUM in gbl')

c test qliu
c      READ(66) DUM
c      CALL G2SPC(DUM)
c end qliu

c      IF(IDX.EQ.1) print *,'TERRAIN AT 289, 80 ',DUM(289,80)
      ENDIF
C
      IF(IDX.EQ.1) THEN
      DO 50 I=1,IMAX
      DO 50 J=1,JMAX
      ZG(I,J) = DUM(I,J)
50    CONTINUE
      ELSEIF(IDX.EQ.2) THEN
      DO 51 I=1,IMAX
      DO 51 J=1,JMAX
      PSFC(I,J) = DUM(I,J)
51    CONTINUE
      ELSEIF(IDX.EQ.3) THEN
      DO 52 I=1,IMAX
      DO 52 J=1,JMAX
      T1(I,J) = DUM(I,J)
52    CONTINUE
      ENDIF
C
c      IF(IDX.EQ.2)call maxmin(PSFC,IMAX*JMAX,1,1,1,'psfc in gbl')
c      IF(IDX.EQ.3)call maxmin(T1,IMAX*JMAX,1,1,1,'T1 in gbl')
      IF(IDX.EQ.3)THEN
      G = 9.8
      R = 287.05
      GAMMA = 6.7*0.001
C
      DO I=1,IMAX
      DO J=1,JMAX
      PS(i,j) = EXP(PSFC(I,J)) * 1000.
      PSFC(I,J) = ALOG(PS(i,j))
      ENDDO
      ENDDO
c      call maxmin(ps,IMAX*JMAX,1,1,1,'sfc press in gbl')
C
C.. Calculate MSLP from SFC Pressure
C
      DO I=1,IMAX
      DO J=1,JMAX
      A = (GAMMA * ZG(I,J)) / T1(I,J)
      B = ALOG(1+A)
      C = (G*B)/(R*GAMMA)
      PSL(I,J) = PSFC(I,J) + C
      ENDDO
      ENDDO
C
      DO I=1,IMAX
      DO J=1,JMAX
      DUMM(I,J) = EXP(PSL(I,J))
      ENDDO
      ENDDO
c      call maxmin(DUMM,IMAX*JMAX,1,1,1,'MSLP in gbl')
c      write(70)DUMM
c
      PSLB=DUMM

      END IF 
     
      DO 189 K=1,KSTM

      IUT=K

c      NWRT1 = 0
      NWT1=0

      SLON=SLON_N(K)
      SLAT=SLAT_N(K) 
      CLON=CLON_N(K)
      CLAT=CLAT_N(K)
      IC=IC_N(K)
      JC=JC_N(K) 
C
      IF (IDX.EQ.1) THEN
      CALL CUT_DM(IMAX,JMAX,GLON,GLAT,ZN,DUM,2)
c      WRITE(IUT) ((ZN(I,J),I=1,IRX),J=JRX,1,-1)
      CALL WRIT1(IUT,NWT1,NWRT1,MTV2,ZN,HDAT)
      WRITE(*,222)K,ITIM,SLON,SLAT,CLON,CLAT,IC,JC
 222  FORMAT(/' STORM ',I2,', FORECAST HOUR ',I4/,
     1       ' SLON,SLAT,CLON,CLAT,IC,JC=',4F10.3,2x,2I5/)
c      print *,'write zn'
      ENDIF
      IF (IDX.EQ.3) THEN
        DO I=1,41
        DO J=1,41
          ZN(I,J)=HDAT(I,J,1,IUT)
        END DO
        END DO
      END IF
      IF (IDX.EQ.3) CALL CUT_DM(IMAX,JMAX,GLON,GLAT,TN,DUM,3)
      IF(IDX.NE.1.AND.IDX.NE.3.AND.IDX.LT.100) THEN
        CALL CUT_DM(IMAX,JMAX,GLON,GLAT,NEW,DUM,3)
      ELSEIF(IDX.GE.100) THEN
        CALL CUT_DM(IMAX,JMAX,GLON,GLAT,NEW,DUM,IDX)
      ENDIF

c      IF(IDX.LE.3)print *,'===at sub SPC2G just bfr call PMSL2PS ==='
c      IF(IDX.EQ.1)call maxmin(zg,IMAX*JMAX,1,1,1,'terrain in gbl')
c      IF(IDX.EQ.1)call maxmin(zn,41*41,1,1,1,'terrain in reg')
c      IF(IDX.EQ.2)call maxmin(psfc,IMAX*JMAX,1,1,1,'sfc pres in gbl')
c      IF(IDX.EQ.2)call maxmin(new,41*41,1,1,1,'sfc pres in reg')
c      IF(IDX.EQ.3)call maxmin(t1,IMAX*JMAX,1,1,1,'temp at k=1 in gbl')
c      IF(IDX.EQ.3)call maxmin(tn,41*41,1,1,1,'temp at k=1 in reg')
c      IF(IDX.LE.3)print *,'======================================='
C
      IF(IDX.EQ.3) CALL PMSL2PS(IMAX,JMAX,GLON,GLAT,
     1                      IUT,MTV2,DUMM,HDAT,ZN,TN)
131   FORMAT(1x,'TERRAIN')
121   FORMAT(1x,20F5.0)

C
      IF(IDX.GT.3) THEN
c      WRITE(IUT)((NEW(I,J),I=1,IRX),J=JRX,1,-1)
      CALL WRIT1(IUT,NWT1,NWRT1,MTV2,NEW,HDAT)
      ENDIF

      IF(K.LT.KSTM)NWRT1=NWRT1-NWT1

 189  CONTINUE
C
      RETURN
      END
C

      SUBROUTINE DECVAR(ISTART,IEND,IVALUE,IERDEC,FMT,BUFF)
C
      PARAMETER (NCHLIN=130)
C
      CHARACTER FMT*(*),BUFF*(*),OUTLIN*1
C
c      SAVE
C
      DIMENSION OUTLIN(NCHLIN)
C
c && 2 comments
CC    WRITE(6,1) FMT,BUFF
CC  1 FORMAT(/'...FMT=',A10,/,' ...BUFF=',A100)
C
      READ(BUFF(ISTART:IEND),FMT,ERR=10)  IVALUE
      IERDEC=0
      RETURN
C
   10 CONTINUE
C
      OUTLIN=' '
C
      IERDEC=10
      OUTLIN(ISTART:IEND)='*'
C
      WRITE(6,31) (OUTLIN(ICH1),ICH1=1,NCHLIN)
      WRITE(6,32) BUFF
   31 FORMAT(/'******ERROR DECODING, BUFF=',/,130A1)
   32 FORMAT(A130)
C
      RETURN
      END


      SUBROUTINE HURR_MESS(NSEM,IMAX,JMAX,GLON,GLAT)
    
      PARAMETER (IRX=41,JRX=41,NST=10)
      PARAMETER (MAXVIT=15)
 
      COMMON/SMTH/ CLAT,CLON
      REAL GLAT(JMAX),GLON(IMAX)
      COMMON /NHC/ KSTM,IC_N(NST),JC_N(NST)
      COMMON /NHC1/ SLON_N(NST),SLAT_N(NST),CLON_N(NST),CLAT_N(NST)
      DIMENSION STMDIR(NST),STMSPD(NST)
c      CHARACTER ST_NAME(NST)*3,TCVT(NST)*95
      CHARACTER ST_NAME(10)*3,STMNAME(10)*3,TCVT(10)*95
      COMMON /STNAME/ST_NAME
      COMMON /TCVIT/TCVT
      COMMON /CHEN/KUNIT,ITIM

      character stmb1*1,stmb2*1,stmnum*2,stmmem*4,ismcxl*1,ismcyl*1
      integer stmymd,stmh,stmx,stmfh

      CHARACTER MEM_READ*4,ENS_MEM*4,STMNAME9*12

      character tmmem*3
      character NS_MEM*3

      COMMON /ENS1/ENS_MEM,idatez,IUTCZ,icycx


      CHARACTER BUFIN(95)*1,BUFY2K(95)*1,STMNAM(NST)*12,STMNMZ*9
      CHARACTER FMTVIT(MAXVIT)*6,BUFINZ*100,LATNS*1,LONEW*1

      DIMENSION IVTVAR(MAXVIT),VITVAR(MAXVIT),VITFAC(MAXVIT),
     1          ISTVAR(MAXVIT),IENVAR(MAXVIT)

      DIMENSION ISTMCX1(NST),ISTMCY1(NST),STMCX(NST),STMCY(NST)
 
      dimension idat(8),jdat(8),rinc(5)

      DATA ISTVAR/20,29,34,39,45,49,53,58,63,68,71,75,80,85,90/
      DATA IENVAR/27,32,36,42,47,51,56,61,66,69,73,78,83,88,93/ 
      DATA VITFAC/2*1.0,2*0.1,1.0,0.1,9*1.0/
      DATA FMTVIT/'(I8.8)','(I4.4)','(I3.3)','(I4.4)',2*'(I3.3)',
     1            3*'(I4.4)','(I2.2)','(I3.3)',4*'(I4.4)'/
   
      EQUIVALENCE (BUFIN(37),LATNS),(BUFIN(43),LONEW),
     1            (BUFIN(10),STMNMZ),(BUFIN(1),BUFINZ)
      EQUIVALENCE (IVTVAR(1),IDATEZ),(IVTVAR(2),IUTCZ)
C
      EQUIVALENCE (VITVAR( 3),STMLTZ),(VITVAR( 4),STMLNZ),
     1            (VITVAR( 5),STMDRZ),(VITVAR( 6),STMSPZ)
C
      DO I=1,10
        SLON_N(I)=0.
        SLAT_N(I)=0.
        CLON_N(I)=0.
        CLAT_N(I)=0.
        IC_N(I)=0
        JC_N(I)=0
      END DO

  90  REWIND 11
      KREC=0
      KSTORM=0
      NERROR=0
C
C  Get the hurricane center from the hurricane message made by NHC
C
C     READ A RECORD INTO BUFFER
C
  100 CONTINUE
      READ(11,101,ERR=990,END=200) (BUFIN(NCH),NCH=1,95)
  101 FORMAT(95A1)

      if(BUFIN(35).eq.'N' .or. BUFIN(35).eq.'S')  then

         print *, ' '
         print *, '==> Read in RECORD from tcvitals file -- contains a',
     $    ' 2-digit year "'
         print *, ' '

         BUFY2K(1:19) = BUFIN(1:19)
         IF(BUFIN(20)//BUFIN(21).GT.'20')  THEN
            BUFY2K(20) = '1'
            BUFY2K(21) = '9'
         ELSE
            BUFY2K(20) = '2'
            BUFY2K(21) = '0'
         ENDIF
         BUFY2K(22:95) = BUFIN(20:93)
         BUFIN = BUFY2K

         print *, ' '
         print *, '==> 2-digit year converted to 4-digit year "'
         print *, ' '

      else  if(BUFIN(37).eq.'N' .or. BUFIN(37).eq.'S')  then

         print *, ' '
         print *, '==> Read in RECORD from tcvitals file -- contains a',
     $    ' 4-digit year "'
         print *, ' '

      else

         print *, ' '
         print *, '***** Cannot determine if this record contains ',
     $    'a 2-digit year or a 4-digit year - skip it and try reading ',
     $    'the next record'
         print *, ' '
         go to 100

      end if

C
C     DECODE DATE AND TIME
C
      DO 110 IV=1,2
      CALL DECVAR(ISTVAR(IV),IENVAR(IV),IVTVAR(IV),IERDEC,FMTVIT(IV),
     1            BUFINZ)
 
  110 CONTINUE

      DO 140 IV=3,MAXVIT
      CALL DECVAR(ISTVAR(IV),IENVAR(IV),IVTVAR(IV),IERDEC,FMTVIT(IV),
     1            BUFINZ)
      VITVAR(IV)=REAL(IVTVAR(IV))*VITFAC(IV)
  140 CONTINUE

C          *****************************************************
C          *****************************************************
C          ****            IMPORTANT NOTES:                 ****
C          ****                                             ****
C          ****    ALL STORM LONGITUDES CONVERTED TO        ****
C          ****    0-360 DEGREES, POSITIVE EASTWARD  !!!    ****
C          ****                                             ****
C          ****    ALL STORM SPEEDS ARE IN M/SEC            ****
C          ****                                             ****
C          ****    ALL DISTANCE DATA ARE IN KM              ****
C          ****                                             ****
C          ****    ALL PRESSURE DATA ARE IN HPA (MB)        ****
C          *****************************************************
C          *****************************************************
C
C     SIGN OF LATITUDE AND CONVERT LONGITUDE
C
      IF(LATNS .EQ. 'S')  THEN
      STMLTZ=-STMLTZ
      ELSE IF(LATNS .NE. 'N')  THEN
      WRITE(6,153) STMLTZ,STMLNZ,LATNS
  153 FORMAT('******ERROR DECODING LATNS, ERROR RECOVERY NEEDED.',
     1       '  STMLTZ,STMLNZ,LATNS=',2F12.2,2X,A1)
      GO TO 100
      ENDIF
C
      IF(LONEW .EQ. 'W')  THEN
      STMLNZ=360.-STMLNZ
      ELSE IF(LONEW .NE. 'E')  THEN
      WRITE(6,157) STMLTZ,STMLNZ,LATNS
  157 FORMAT('******ERROR DECODING LONEW, ERROR RECOVERY NEEDED.',
     1       '  STMLTZ,STMLNZ,LATNS=',2F12.2,2X,A1)
      ENDIF
C
      IF(STMLNZ.gt.345..or.STMLNZ.lt.15.)go to 100
!      IF(STMLNZ.gt.340..or.STMLNZ.lt.20.)go to 100

      KREC=KREC+1

      DO I=1,3
        ST_NAME(KREC)(I:I)=BUFIN(I+5)
      END DO
      DO I=1,95
        TCVT(KREC)(I:I)=BUFIN(I)
      END DO
c
      IF(KSTORM .LT. 10)  THEN
      KSTORM=KSTORM+1
      CLAT_N(KSTORM)=STMLTZ
      CLON_N(KSTORM)=STMLNZ
      STMDIR(KSTORM)=STMDRZ
      STMSPD(KSTORM)=STMSPZ
      STMNAM(KSTORM)=STMNMZ
      GO TO 100
C
      ELSE

  300 WRITE(6,301) KSTORM
  301 FORMAT(/'******KSTORM EXCEEDS AVAILABLE SPACE, KSTORM=',I5
     1       ,/,' Results may have serious problem')
      GO TO 200

      ENDIF

  200 IF(KSTORM .GT. 0)  THEN
      WRITE(6,201)KSTORM,KREC
  201 FORMAT(/'...FOUND STORM IN VITALS FILE.',/,4X,I5,
     2       ' TOTAL NUMBER OF RECORDS READ=',I7)
      ELSE
      WRITE(6,202)
  202 FORMAT(/'NO STORM FOUND IN VITALS FILE.')
      CALL W3TAGE('GEFS_VORTEX_SEPARATE')
      CALL ERREXIT(56)
      END IF
C
c  Correct to the storm center position

      PI=ATAN(1.0)*4.E+00
      PI180 = PI/180.
      DT=(float(ITIM)-6.)*3600.                     !  Second
      ONEDEG=360./(2.*PI*6.37E6)                    !  Degree/Meter
      FACT=DT*ONEDEG

      KSTM=KSTORM

c      WRITE(12, 233) KSTM
c 233  FORMAT(2x,I5)

      DO I=1,KSTM

      WRITE(*,430)STMNAM(I),CLAT_N(I),CLON_N(I),STMDIR(I),STMSPD(I)
  430 FORMAT(/' STORM NAME: ',A12,/, ' READIN STORM CENTER=',2F12.4,
     1       /,' STORM DIR and SPEED: ',2F12.4)

cnew        USTM=STMSPD(I)*SIN(PI180*STMDIR(I))
cnew        VSTM=STMSPD(I)*COS(PI180*STMDIR(I))
cnew        CLON_N(I)=CLON_N(I)+USTM*FACT/COS(PI180*CLAT_N(I))
cnew        CLAT_N(I)=CLAT_N(I)+VSTM*FACT

cnew        PRINT*, 'CORRECTED STORM CENTER AT TIME HOUR ',ITIM,' =',
cnew     1           CLON_N(I),CLAT_N(I)

      END DO

      IF(NSEM.eq.1)ENS_MEM='AC00'
      IF(NSEM.eq.3)ENS_MEM='AN01'
      IF(NSEM.eq.4)ENS_MEM='AP01'
      IF(NSEM.eq.5)ENS_MEM='AN02'
      IF(NSEM.eq.6)ENS_MEM='AP02'
      IF(NSEM.eq.7)ENS_MEM='AN03'
      IF(NSEM.eq.8)ENS_MEM='AP03'
      IF(NSEM.eq.9)ENS_MEM='AN04'
      IF(NSEM.eq.10)ENS_MEM='AP04'
      IF(NSEM.eq.11)ENS_MEM='AN05'
      IF(NSEM.eq.12)ENS_MEM='AP05'
      IF(NSEM.eq.13)ENS_MEM='AN06'
      IF(NSEM.eq.14)ENS_MEM='AP06'
      IF(NSEM.eq.15)ENS_MEM='AN07'
      IF(NSEM.eq.16)ENS_MEM='AP07'
      IF(NSEM.eq.17)ENS_MEM='AN08'
      IF(NSEM.eq.18)ENS_MEM='AP08'
      IF(NSEM.eq.19)ENS_MEM='AN09'
      IF(NSEM.eq.20)ENS_MEM='AP09'
      IF(NSEM.eq.21)ENS_MEM='AN10'
      IF(NSEM.eq.22)ENS_MEM='AP10'
      IF(NSEM.eq.23)ENS_MEM='AN11'
      IF(NSEM.eq.24)ENS_MEM='AP11'
      IF(NSEM.eq.25)ENS_MEM='AN12'
      IF(NSEM.eq.26)ENS_MEM='AP12'
      IF(NSEM.eq.27)ENS_MEM='AN13'
      IF(NSEM.eq.28)ENS_MEM='AP13'
      IF(NSEM.eq.29)ENS_MEM='AN14'
      IF(NSEM.eq.30)ENS_MEM='AP14'
      IF(NSEM.eq.31)ENS_MEM='AN15'
      IF(NSEM.eq.32)ENS_MEM='AP15'
      IF(NSEM.eq.33)ENS_MEM='AN16'
      IF(NSEM.eq.34)ENS_MEM='AP16'
      IF(NSEM.eq.35)ENS_MEM='AN17'
      IF(NSEM.eq.36)ENS_MEM='AP17'
      IF(NSEM.eq.37)ENS_MEM='AN18'
      IF(NSEM.eq.38)ENS_MEM='AP18'
      IF(NSEM.eq.39)ENS_MEM='AN19'
      IF(NSEM.eq.40)ENS_MEM='AP19'
      IF(NSEM.eq.41)ENS_MEM='AN20'
      IF(NSEM.eq.42)ENS_MEM='AP20'

      NS_MEM=ENS_MEM(2:4)

      K1STM=0
      I=0
c rlw replace this read (for 24h cycle) with atcf read 
      icycx=6
c decrement date and time by icycx for test
      rinc(1)=0.0
      rinc(2)=-icycx
      rinc(3:5)=0.0
      idat(1)=idatez/10000
      idat(2)=(idatez-10000*idat(1))/100
      idat(3)=idatez-10000*idat(1)-100*idat(2)
      idat(4)=0.0
       if(iutcz.ge.100) then
      idat(5)=iutcz/100
      else
      idat(5)=iutcz
      endif
      idat(6:8)=0.0
      call w3movdat(rinc,idat,jdat)
      idatezm=10000*jdat(1)+100*jdat(2)+jdat(3)
      iutczm=jdat(5)
      if ( icycx .eq. 24 ) then
      DO MEM=1,100
        READ(40,442,end=436)MEM_READ,
     &    ISMCY,ISMCX,STMNAME9
        IF(MEM_READ.EQ.ENS_MEM)THEN
          I=I+1
          STMCX(I)=360.-ISMCX*0.1
          STMCY(I)=ISMCY*0.1
          STMNAME(I)=STMNAME9
          K1STM=K1STM+1
        END IF
      END DO
 442  FORMAT(2x,A4,16x,2i4,41x,A3)
      else
      rewind (40)
      print*,' '
      print*,'diagnostic for read tracking begin'
      DO MEM=1,10000000
        read(40,4433,end=436)
     &    stmb1,stmb2,stmnum,stmymd,stmh,stmx,stmmem,stmfh,
     &    ismcy,ismcyl,ismcx,ismcxl
	tmmem=stmmem(2:4)
c       IF(stmmem.EQ.ENS_MEM)THEN
        IF( tmmem.EQ. NS_MEM)THEN
	 if (stmymd.eq.idatezm) then
	 if (stmh.eq.IUTCZm) then
	 if (stmfh.eq.icycx) then
          I=I+1
          IF(ismcxl.eq.'W')then
            STMCX(I)=360.-ISMCX*0.1
          ELSE
            STMCX(I)=ISMCX*0.1
          END IF
          STMCY(I)=ISMCY*0.1
          STMNAME(I)=stmnum(1:2)//stmb1(1:1)
          K1STM=K1STM+1
          PRINT*,' CT STORM Model CENTER at ',
     &          STMNAME(I),STMCX(I),STMCY(I)
	  print*,k1stm,stmb1,stmb2,stmnum,stmymd,stmh,stmx,stmmem,
     &    stmfh,ismcx,ismcxl,ismcy,ismcyl
         else
          print*,'stmfh does not equal icycx ',stmfh,' ',icycx
	 end if
         else
          print*,'stmh does not equal iutczm ',stmh,' ',iutczm
	 end if
         else
          print*,'stmymd does not equal idatezm ',stmymd,' ',idatezm
	 end if
         else
          print*,'tmmem does not equal ns_mem ',stmmem,' ',ens_mem
        END IF
      END DO
      print*,'diagnostic for read tracking end'
      print*,' '
 4433 format(2a1,2x,a2,2x,i8,i2,1x,i3,2x,a4,1x,i4,1x,i4,a1,1x,i5,a1)
      end if
c rlw end replacement for cycle length
 436  CONTINUE

      REWIND 30

C      DO I=1,KSTM
C       DO K=1,K1STM
C         print*,ST_NAME(i),stmname(k),'STNAME and stmname'
C         IF(STMNAME(K).EQ.ST_NAME(I))THEN
C           CLON_N(I)=STMCX(K)
C           CLAT_N(I)=STMCY(K)
C           PRINT*, ' CT STORM OBS. CENTER at ',
C    &               STMNAME(K),CLON_N(I),CLAT_N(I)
C         END IF
C       END DO
C     END DO


      DO 900 I=1,KSTM

      CLON=CLON_N(I)
      CLAT=CLAT_N(I)
 
      AMN = 500.
      DO 10 ILA = 1,JMAX
      DMN = ABS (GLAT(ILA) - CLAT)
C
      IF (DMN.LE.AMN) THEN
      AMN = DMN
      JC  = ILA
      ENDIF
C
10    CONTINUE
C
      BMN = 500.
      DO 20 ILO = 1,IMAX
      OMN = ABS (GLON(ILO) - CLON)
C
      IF (OMN.LE.BMN) THEN
      BMN = OMN
      IC  = ILO
      ENDIF
C
20    CONTINUE

      IC_N(I)=IC
      JC_N(I)=JC
C    
      PRINT *,'  '
c      PRINT *,'==========AT SUB HURR_MESS============='
c      PRINT *,'... 1st guess ... center of hurricane'
c      PRINT *,'===IC,JC=== ',IC,JC,GLON(IC),GLAT(JC)
c      PRINT *,'==DIST OF CLON AND IC===',BMN
c      PRINT *,'==DIST OF CLAT AND JC===',AMN

      SLON_N(I) = IFIX(GLON(IC)+0.5 - IRX/2)
      SLAT_N(I) = IFIX(GLAT(JC)+0.5 - JRX/2)
      PRINT *,' '
c      PRINT *,'=========================================='
c      PRINT *,'SLAT, SLON = ', SLAT_N(I),SLON_N(I)
c      WRITE(12,123)SLON_N(I),SLAT_N(I),CLON_N(I),CLAT_N(I)
c123   FORMAT(1x,4F10.3)
      PRINT *,'=========================================='

  900 CONTINUE

      RETURN

  990 WRITE(6,991) BUFIN
  991 FORMAT('******ERROR READING STORM RECORD.  BUFIN IS:',/,
     1       ' ******',A95,'******')
      GO TO 100
      RETURN

      END
C

      SUBROUTINE CUT_DM(IMAX,JMAX,GLON,GLAT,NEW,OLD,IV)
C
      PARAMETER (IRX=41,JRX=41)

      COMMON/SMTH/ CLAT,CLON
      REAL GLAT(JMAX),GLON(IMAX),OLD(IMAX,JMAX)
      COMMON/CNT/ SLON,SLAT
      REAL NEW(IRX,JRX)
C
      X=360./FLOAT(IMAX)
      DO 10 J=1,JRX
      BLA = 90. - SLAT - (J-1)
      DO 10 I=1,IRX
      BLO = SLON + (I-1)
      IF(BLO.GT.360.)BLO=BLO-360.
C
      DO 20 IG=IMAX,1,-1
      DON = BLO - GLON(IG)
      IF (DON.GE.0) THEN
      DX = DON
      IX = IG
      GO TO 1
      ENDIF
20    CONTINUE
C
1     DO 30 JG=JMAX,1,-1
      GLA = 90 - GLAT(JG)
      DAT = BLA - GLA
      IF (DAT.GE.0) THEN
      DY = DAT
      IY = JG
      Y = GLAT(JG)-GLAT(JG+1)
      GO TO 2
      ENDIF
30    CONTINUE
C
2     IF (IV.EQ.2) THEN
        DD1 = SQRT(DX**2.+DY**2.)
        DD2 = SQRT(DX**2.+(Y-DY)**2.)
        DD3 = SQRT((X-DX)**2.+DY**2.)
        DD4 = SQRT((X-DX)**2.+(Y-DY)**2.)
        IF(DD1.LE.0.2) THEN
          NEW(I,J) = OLD(IX,IY)
          GO TO 10
        ENDIF
        IF(DD2.LE.0.2) THEN
          NEW(I,J) = OLD(IX,IY+1)
          GO TO 10
        ENDIF
        IF(DD3.LE.0.2) THEN
          NEW(I,J) = OLD(IX+1,IY)
          GO TO 10
        ENDIF
        IF(DD4.LE.0.2) THEN
          NEW(I,J) = OLD(IX+1,IY+1)
          GO TO 10
        ENDIF
      ENDIF 
C
      X1 = ( DY*OLD(IX  ,IY+1) + (Y-DY)*OLD(IX  ,IY) ) / Y
      X2 = ( DY*OLD(IX+1,IY+1) + (Y-DY)*OLD(IX+1,IY) ) / Y
      Y1 = ( DX*OLD(IX+1,IY  ) + (X-DX)*OLD(IX,IY  ) ) / X
      Y2 = ( DX*OLD(IX+1,IY+1) + (X-DX)*OLD(IX,IY+1) ) / X
      XX = (DX*X2 + (X-DX)*X1)/X 
      YY = (DY*Y2 + (Y-DY)*Y1)/Y
      NEW(I,J) = (XX+YY)/2.
c      xxxxx=0.25*(OLD(IX,IY)+OLD(IX+1,IY)+
c     &            OLD(IX,IY+1)+OLD(IX+1,IY+1))
C
c      IF(IV.GE.100) THEN
C
c      IF(I.LE.30.AND.J.EQ.20)THEN
c      print *,'OLD 1,2,3,4 ',
c     1     OLD(IX,IY),OLD(IX+1,IY),OLD(IX,IY+1),OLD(IX+1,IY+1)
c      print *,'X,Y,DX,DY ',X,Y,DX,DY
c      print *,'X1,X2,Y1,Y2 ',x1,x2,y1,y2
c      print *,'XX, YY  ',XX,YY
c      print *,'NEW  ',NEW(I,J)
c      PRINT *,'LAT, LON at SM Domain  ',SLAT+(J-1),SLON+(I-1)
c      PRINT *,'LAT, LON at Gauss grid ',GLAT(IY),GLON(IX)
c      PRINT *,'IX,IY  ',IX,IY
c      print *,'BLA, BLO, GLA, GLO ',BLA, BLO, GLA, GLON(IX)
c      ENDIF
c      ENDIF
C
10    CONTINUE
C
      RETURN
      END

 
      SUBROUTINE WRIT1(IUT,NWT1,NWRT1,MTV2,DIN,HDAT)
      PARAMETER (IRX=41,JRX=41,NST=10)
      REAL       DIN(IRX,JRX),HDAT(IRX,JRX,MTV2,NST) 
      NWRT1=NWRT1+1
      NWT1=NWT1+1
c      PRINT*,'WRIT1 COUNT = ',NWRT1,NWT1,IUT
      DO J=1,JRX
      DO I=1,IRX
        HDAT(I,J,NWRT1,IUT)=DIN(I,J)
      END DO
      END DO 
      END

      SUBROUTINE READ1(IUT,NRED1,MTV3,DOUT,PDAT)
      PARAMETER (IRX=41,JRX=41)
      REAL DOUT(IRX,JRX),PDAT(IRX,JRX,MTV3)
      NRED1=NRED1+1
c      PRINT*,'READ1 COUNT = ',NRED1
      DO J=1,JRX
      DO I=1,IRX
        DOUT(I,J)=PDAT(I,J,NRED1)
      END DO
      END DO 
      END

      SUBROUTINE WRIT2(IMAX,JMAX,NWRT2,MTV,DIN,HDATA)
      REAL DIN(IMAX,JMAX),HDATA(IMAX,JMAX,MTV)
      NWRT2=NWRT2+1
c      PRINT*,'WRIT2 COUNT = ',NWRT2
c      call maxmin(DIN,IMAX*JMAX,1,1,1,'DIN in gbl')
      DO J=1,JMAX
      DO I=1,IMAX
        HDATA(I,J,NWRT2)=DIN(I,J)
      END DO
      END DO
      END

      SUBROUTINE READ2(IMAX,JMAX,NRED2,MTV,DOUT,HDATA)
      REAL DOUT(IMAX,JMAX),HDATA(IMAX,JMAX,MTV)
      NRED2=NRED2+1
c      PRINT*,'READ2 COUNT = ',NRED2
      DO J=1,JMAX
      DO I=1,IMAX
        DOUT(I,J)=HDATA(I,J,NRED2)
      END DO
      END DO
      END


      SUBROUTINE HURR_REL(NSEM,MWAVE,IMAX,JMAX,KMAX,IKMAX,MAXWV2,
     1                       JHF,MTV,MTV1,MTV2,MTV3,
     2                       HDAT,HDATA,PDAT,SKIP2,PSLB,SL,
     3                       nvcd,idvc,idsl,vcrd,datao)

c      SUBROUTINE HURR_REL(MWAVE,KMAX,MAXWV2,
c     1                       MTV,MTV1,MTV2,MTV3,
c     2                       HDAT,HDATA,PDAT,SKIP2,PSLB)

C
C SEPARATE HURRICANE VORTEX FROM ENVIRONMENTAL FIELD, THEN
C RELOCATE THE HURRICANCE VORTEX TO NEW LOCATION 
C      REF, Kurihara et al 1992, 1995. MWR
C

      use sigio_module
      use sigio_r_module

      type(sigio_data) datao

      PARAMETER (IX=41,JX=41,NF=11,IT=24,IR=120,IJ=IX*JX)
      PARAMETER (NSG=8000)
      PARAMETER (NST=10)
c      PARAMETER (IMAX=384,JMAX=190,NSG=8000)
c      PARAMETER (JHF=JMAX/2,NST=10)
C
      DIMENSION U(IX,JX),V(IX,JX),UD(IX,JX),US(IX,JX),VS(IX,JX)
      DIMENSION SKIP(IX,JX),M(11),FK(NF),TW(IT,IR)
      DIMENSION VD(IX,JX),XTU(IX,NF),XTV(IX,NF),DKY(IX,JX)
      DIMENSION YTU(IX,JX),YTV(IX,JX),RS(IT),R0(IT),RF(IT)
!      DIMENSION INP(IJ),JNP(IJ),CM(IJ),DIST(IJ)
      DIMENSION ALAT(JX),ALON(IX),ZG(IX,JX),DATG(IMAX,JMAX)
      DIMENSION GLON(IMAX,JMAX),GLAT(IMAX,JMAX),ZDATG(IMAX,JMAX)
      DIMENSION ING(NSG),JNG(NSG)
      REAL COLRAD(JHF), WGT(JHF),WGTCS(JHF),RCS2(JHF)
      COMMON /ST/ALON,ALAT

      COMMON /NHC/ KSTM1,IC_N(NST),JC_N(NST)
      COMMON /NHC1/SLON_N(NST),SLAT_N(NST),CLON_N(NST),CLAT_N(NST)

      COMMON /NHC2/MDX,MDY
      COMMON /NHC3/AMDX,AMDY
      COMMON /POSIT/CLON_NEW,CLAT_NEW,SLON,SLAT,CLON,CLAT,RAD                   
      COMMON /vect/R0,XVECT(IT),YVECT(IT)      
      COMMON /TR/ING,JNG,IB
c      COMMON /TR/ZDATG,GLON,GLAT,ING,JNG,IB
      COMMON /CHNL/IUT,KSTM

      character stmb1*1,stmb2*1,stmnum*2,stmmem*4,ismcxl*1,ismcyl*1
      integer stmymd,stmh,stmx,stmfh

      CHARACTER MEM_READ*4,ENS_MEM*4,STMNAME9*12

      COMMON /ENS1/ENS_MEM,idatez,IUTCZ,icycx

      COMMON /HDAT1/NWRT1,NRED1,NWT1
      COMMON /HDAT3/NWRT2,NRED2
      REAL PSLB(IMAX,JMAX)
      REAL(4) SL(KMAX)
      REAL HDAT(IX,JX,MTV2,NST),HDATA(IMAX,JMAX,MTV)
      REAL PDAT(IX,JX,MTV3)
      REAL HSIG(IX,JX,KMAX),HP(IX,JX,2*KMAX+1)

      INTEGER ISTMCX1(NST),ISTMCY1(NST)
      REAL    STMCX(NST),STMCY(NST)
      CHARACTER ST_NAME(NST)*3,STMNAME(NST)*3,TCVT(NST)*95
      COMMON /STNAME/ST_NAME
      COMMON /TCVIT/TCVT
      COMMON /CHEN/KUNIT,ITIM

!      REAL(4) FHOUR,DUMMY(245)
      REAL(4) SKIP2(MAXWV2,MTV1+IKMAX)
!      CHARACTER*8 LAB(4)
      DIMENSION IDATE(4)
      DIMENSION DKM(IX,JX)
      DIMENSION ENV(IX,JX,MTV2),ENV1(IX,JX,MTV3)
 
      DIMENSION vcrd(KMAX+1,nvcd)

      character tmmem*3
      character NS_MEM*3
      character stmb*2
cc
      REAL(4),ALLOCATABLE :: WORK_3(:)
      REAL,   ALLOCATABLE :: WK_S1(:,:),WK_S2(:,:),WK_G(:,:,:)
      
!      COMMON /COEF1/LAB
      COMMON /COEF2/IDATE
!      COMMON /COEF3/FHOUR,DUMMY
      COMMON /COEF5/NCNT,NCNT2
C
      DATA M/2,3,4,2,5,6,7,2,8,9,2/
C
      ALLOCATE ( WORK_3(MAXWV2) )
      ALLOCATE ( WK_S1(MAXWV2,KMAX),WK_S2(MAXWV2,KMAX) )
      ALLOCATE ( WK_G(IMAX,JMAX,KMAX) )

      NCNT2 = 0

      DO LO = 1,NSG
      ING(LO) = 0
      JNG(LO) = 0
      ENDDO
C
      CALL GLATS(JHF,COLRAD,WGT,WGTCS,RCS2)
C
      PI=ASIN(1.)*2
      RAD=PI/180.
C
      DO I = 1,IMAX
      DO LL = 1,JHF 
      LLS = JMAX+1 - LL
      GLAT(I,LL)  = 90. - COLRAD(LL)/RAD
      GLAT(I,LLS) = -GLAT(I,LL)
      ENDDO
      ENDDO
C
      DLN = 360.0/FLOAT(IMAX)
      DO J = 1,JMAX
      DO LN = 1,IMAX
      GLON(LN,J) = (LN-1) * DLN
      ENDDO
      ENDDO
C
c      REWIND 12
c      REWIND 20

cql      READ(20)LAB
c      WRITE(6,124) LAB
124   FORMAT(4A8)
!!      WRITE(KUNIT) LAB
      WRITE(6,210) (IDATE(I),I=1,4),FHOUR
c     1            ,(DUMMY(K),K=1,2*KMAX+1)
210   FORMAT(5X,' INPUT DATE AND FCST HOUR ',4I5,F7.1/(2X,G13.6))
!      WRITE(KUNIT)FHOUR,(IDATE(I),I=1,4),DUMMY
cql      READ(20)(GZ(NW),NW=1,MAXWV2)
      NCNT2 = NCNT2 +1
      DO NW=1,MAXWV2
       WORK_3(NW)=SKIP2(NW,NCNT2)
       datao%ps(nw)=work_3(nw)
      END DO
!      WRITE(KUNIT)(WORK_3(NW),NW=1,MAXWV2)
cql      READ(20)SKIP2
      NCNT2 = NCNT2 + 1

c      WRITE(KUNIT)(SKIP2(NW),NW=1,MAXWV2)
C
      DO I=1,NF
      FK(I)=0.5/(1-COS(2.*PI/M(I)))
      ENDDO
C
c      READ(12, 233) KSTM
c 233  FORMAT(2x,I5)
      KSTM = KSTM1

      WRITE(*,244) KSTM
 244  FORMAT('NUMBER OF STORMS: ',I5)
      idatezm=idate(4)*10000+idate(2)*100+idate(3)
      iutczm=idate(1)
      K1STM=0
      I=0
c rlw replace this read (for 24h cycle) with atcf read 
      icycx=6
      if ( icycx .eq. 24 ) then
      DO MEM=1,100
        READ(40,442,end=436)MEM_READ,
     &    ISMCY,ISMCX,STMNAME9
        IF(MEM_READ.EQ.ENS_MEM)THEN
          I=I+1
          ISTMCY1(I)=ISMCY
          ISTMCX1(I)=ISMCX
          STMCX(I)=360.-ISMCX*0.1
          STMCY(I)=ISMCY*0.1
          STMNAME(I)=STMNAME9
          K1STM=K1STM+1
          PRINT*,' CT STORM Model CENTER at ',
     &          STMNAME(I),STMCX(I),STMCY(I)
        END IF
      END DO
 442  FORMAT(2x,A4,16x,2i4,41x,A3)
      else
      rewind (40)
      DO MEM=1,10000000
        read(40,4433,end=436)
     &    stmb1,stmb2,stmnum,stmymd,stmh,stmx,stmmem,stmfh,
     &    ismcy,ismcyl,ismcx,ismcxl
          
        tmmem=stmmem(2:4)
        ns_mem=ens_mem(2:4)
        IF(tmmem.EQ.NS_MEM)THEN
c        IF(stmmem.EQ.ENS_MEM)THEN
         if (stmymd.eq.idatezm) then
         if (stmh.eq.IUTCZM) then
         if (stmfh.eq.icycx) then
          I=I+1
          IF(ismcxl.eq.'W')then
            STMCX(I)=360.-ISMCX*0.1
          ELSE
            STMCX(I)=ISMCX*0.1
          END IF
          STMCY(I)=ISMCY*0.1
          STMNAME(I)=stmnum(1:2)//stmb1(1:1)
          stmb=stmb1(1:1)//stmb2(1:1)  
           write(*,*)stmb
          if(stmb.eq.'AL') STMNAME(I)=stmnum(1:2)//'L'
          if(stmb.eq.'IO')then
            if(stmcx(i).le.75) then
c    Arabain Sea
            STMNAME(I)=stmnum(1:2)//'A'
            else
c   Bay of Bengal
            STMNAME(I)=stmnum(1:2)//'B'
            endif
           endif
           if(stmb.eq.'SH')then
c South IO
             if(stmcx(i).le.135.and.stmcx(i).ge.20) then
                  STMNAME(I)=stmnum(1:2)//'S'
             elseif(stmcx(i).gt.135.and.stmcx(i).le.300)then
c South Pacific
                 STMNAME(I)=stmnum(1:2)//'P'
             else
c South Atlantic
                 STMNAME(I)=stmnum(1:2)//'Q'
             endif
           endif

          K1STM=K1STM+1
          PRINT*,' CT STORM Model CENTER n HURR_REL at ',
     &          STMNAME(I),STMCX(I),STMCY(I)
          print*,k1stm,stmb1,stmb2,stmnum,stmymd,stmh,stmx,stmmem,
     &    stmfh,ismcx,ismcxl,ismcy,ismcyl
         end if
         end if
         end if
        END IF
      END DO
 4433 format(2a1,2x,a2,2x,i8,i2,1x,i3,2x,a4,1x,i4,1x,i4,a1,1x,i5,a1)
      end if
c rlw end replacement for cycle length
 436  CONTINUE

      IF(NSEM.EQ.1)THEN
!        NCHT=70+NSEM
        NCHT=71
        WRITE(NCHT)KSTM
      ELSE
        NCHT=74
        WRITE(NCHT)KSTM
      END IF


      DO 788 KST=1,KSTM
      
c      IUT=89+KST
        IUT=KST

        IF(NSEM.EQ.1)THEN
!          NCHT=70+NSEM
          NCHT=71
          WRITE(NCHT)ST_NAME(KST)
        ELSE
          NCHT=74
          WRITE(NCHT)ST_NAME(KST)
        END IF

C
        DO K=1,MTV2
        DO J=1,JX
        DO I=1,IX
          ENV(I,J,K)=HDAT(I,J,K,KST)
        END DO
        END DO
        END DO

        PSC_MX=0.
        DO J=1,JX
        DO I=1,IX
          IF(PSC_MX.LT.ENV(I,J,2))PSC_MX=ENV(I,J,2)
        END DO
        END DO
        PSC_MX1=EXP(PSC_MX)*1000.+500.0       
        PRINT*,'MAX SFC PRESS=',PSC_MX1

        CALL SIG2P(KMAX,MTV2,MTV3,ENV(1,1,1),PDAT(1,1,1),
     &             PSC_MX1,HSIG,HP,KST,nvcd,idvc,idsl,vcrd)

      NWRT1 = 0
      NWRT2 = 0
      NRED1 = 0
      NRED2 = 0

      CALL READ2(IMAX,JMAX,NRED2,MTV,ZDATG,HDATA)

c     WRIT2(NWRT2,MTV,ZDATG,HDATA)
      NWRT2 = 1

      CALL READ1(IUT,NRED1,MTV3,ZG,PDAT)

      call maxmin(zg,ix*jx,1,1,1,'regional terrain')
      IFLAG=0
      DO J=1,JX
      DO I=1,IX
        IF(ZG(I,J).GT.500.)THEN
          IFLAG=1
c          PRINT*,'Max Terrain Height > 200 m'
          GO TO 443
        END IF
      END DO
      END DO
 443  CONTINUE
C

C.. READ U, V at ~850 mb

!      K850=3+KMAX+(KMAX/4)*4+1
      K8501=1
      DIST2=ABS(SL(1)-0.85)
      DO K=1,KMAX
        DIST1=ABS(SL(K)-0.85)
        IF(DIST1.LT.DIST2)THEN
          K8501=K
          DIST2=DIST1
        END IF
      END DO

! Be consistent with 2001 operational model for KMAX=42
! set K8501=K8501+1
      IF(KMAX.EQ.42) K8501=K8501+1  
 
      K850=3+KMAX+4*(K8501-1)+1

      IF(K8501.LT.1.OR.K8501.GT.KMAX)THEN
        PRINT*,'K8501 is out of bound'
        STOP
      END IF 

      PRINT*,'QLIUQLIU test',K850
      
      NRED1 = NRED1 + K850
      DO J=1,JX
      DO I=1,IX
        U(I,J)=HDAT(I,J,K850+2,KST)
        V(I,J)=HDAT(I,J,K850+3,KST)
      END DO
      END DO
        
C
c qliu
c get Hurricane Center
c      READ(12,123)SLON,SLAT,CLON_NHC,CLAT_NHC
c123   FORMAT(1X,4F10.2)
      SLON = SLON_N(KST)
      SLAT = SLAT_N(KST)
      CLON_NHC = CLON_N(KST)
      CLAT_NHC = CLAT_N(KST)

      CLON = SLON+20.
      CLAT = SLAT+20.
c      PRINT*,'CLON, CLAT, SLON, SLAT=',CLON, CLAT, SLON, SLAT
c      PRINT*,'CLON_NHC,CLAT_NHC=',CLON_NHC,CLAT_NHC
c      fact=cos(CLAT*rad)
      fact=1.0
      do j=1,jx
      do i=1,ix
! East-West wind in new coordinate (phi,theta)
! this conversion only affects Hurrican Center determination and R0
        U(I,J)=U(I,J)/fact      
      end do
      end do
C.. DO ZONAL FILTER
C
      DO 100 J=1,JX
      DO N=1,NF
      XTU(1,N)  = U(1,J)
      XTU(IX,N) = U(IX,J)
      XTV(1,N)  = V(1,J)
      XTV(IX,N) = V(IX,J)
      ENDDO
C
      DO I=2,IX-1
      XTU(I,1) = U(I,J)+FK(1)*(U(I-1,J)+U(I+1,J)-2.*U(I,J))
      XTV(I,1) = V(I,J)+FK(1)*(V(I-1,J)+V(I+1,J)-2.*V(I,J))
      ENDDO
C
      DO N=2,NF
      DO I=2,IX-1
      XTU(I,N)=XTU(I,N-1)+FK(N)*(XTU(I-1,N-1)+XTU(I+1,N-1)-2.
     1         *XTU(I,N-1))
      XTV(I,N)=XTV(I,N-1)+FK(N)*(XTV(I-1,N-1)+XTV(I+1,N-1)-2.
     1         *XTV(I,N-1))
      ENDDO
      ENDDO
C
      DO I=1,IX
      US(I,J) = XTU(I,NF)
      VS(I,J) = XTV(I,NF)
      ENDDO
C
100   CONTINUE
C
C.. DO MERIDIONAL FILTER 
C
      DO 200 I=1,IX
C
      DO N=1,NF
      YTU(1,N)  = US(I,1)
      YTU(JX,N) = US(I,JX)
      YTV(1,N)  = VS(I,1)
      YTV(JX,N) = VS(I,JX)
      ENDDO
C
      DO J = 2 , JX-1
      YTU(J,1) = US(I,J) + FK(1)*(US(I,J-1) + US(I,J+1)
     *                          -2.*US(I,J))
      YTV(J,1) = VS(I,J) + FK(1)*(VS(I,J-1) + VS(I,J+1)
     *                          -2.*VS(I,J))
      ENDDO     
CC
      DO N = 2 , NF
      DO J = 2 , JX-1
      YTU(J,N) = YTU(J,N-1) + FK(N)*(YTU(J-1,N-1)  +
     *              YTU(J+1,N-1) - 2.*YTU(J,N-1))
      YTV(J,N) = YTV(J,N-1) + FK(N)*(YTV(J-1,N-1)  +
     *              YTV(J+1,N-1) - 2.*YTV(J,N-1))
      ENDDO
      ENDDO
C
      DO J = 1 , JX
      US(I,J)   =  YTU(J,NF)
      VS(I,J)   =  YTV(J,NF)
      ENDDO   
200   CONTINUE
C
C.. GET THE DISTURBANCE FIELD
C
      DO I=1,IX
      DO J=1,JX
      UD(I,J) = U(I,J) - US(I,J)
      VD(I,J) = V(I,J) - VS(I,J)
      ENDDO
      ENDDO
c      WRITE(39) ((U(I,J),I=1,IX),J=Jx,1,-1)
c      WRITE(39) ((V(I,J),I=1,IX),J=Jx,1,-1)
c      WRITE(39) ((US(I,J),I=1,IX),J=Jx,1,-1)
c      WRITE(39) ((VS(I,J),I=1,IX),J=Jx,1,-1)
c      WRITE(39) ((UD(I,J),I=1,IX),J=Jx,1,-1)
c      WRITE(39) ((VD(I,J),I=1,IX),J=Jx,1,-1)
C
C.. FIND NEW VORTEX CENTER
C
      DO I=1,IX
        ALON(I)=SLON+(I-1)
      END DO
      DO J=1,JX
        ALAT(J)=SLAT+(J-1)
      END DO   

c      CALL FIND_NEWCT1(UD,VD)
      CALL FIND_NEWCT(UD,VD)

      ICHEK=0
      CLON_TIM=0.
      CLAT_TIM=0.
      DO I=1,K1STM
        IF(STMNAME(I).EQ.ST_NAME(KST))THEN
          CLON_TIM=STMCX(I)
          CLAT_TIM=STMCY(I)
          ICHEK=1
          GO TO 446
        END IF
      END DO
 446  CONTINUE
      IF((ICHEK.EQ.1).AND.(ABS(CLON_TIM).LT.359.5))THEN
        CLON_NEW=CLON_TIM
        CLAT_NEW=CLAT_TIM
      ELSE
        PRINT*,'GFDL CENTER= ',CLON_NEW,CLAT_NEW,
     &stmname(i),st_name(kst)
        IF(NSEM.LT.1)THEN
          CLON_NEW=CLON_NHC
          CLAT_NEW=CLAT_NHC
        ELSE
          CLON_NEW=CLON_NEW
          CLAT_NEW=CLAT_NEW
        END IF
      ENDIF

C
C.. CALCULATE TANGENTIAL WIND AROUND CIRCLE 
C             24 DIRECTION, RADIALLY 0.1DEG INTERVAL 
C
      CALL TWIND(UD,VD,TW)
C
C.. CALCULATE STARTING POINT AT EACH DIRECTION
C
      CALL STRT_PT(RS,TW,RFAVG)
C
C.. DETERMINE FILTER DOMAIN D0 (=1.25*Rf)
C
      CALL FILTER(RS,TW,RF,RFAVG)

      AMDX=CLON_NHC-CLON_NEW
      AMDY=CLAT_NHC-CLAT_NEW
      MDX=IFIX((CLON_NHC-CLON_NEW)/DLN)

!      IF(ITIM.EQ.6)THEN
        WRITE(52,65)TCVT(KST)(1:32),
     &             CLON_NHC,CLAT_NHC,CLON_NEW,
     &             CLAT_NEW,CLON_TIM,CLAT_TIM,AMDX,AMDY,
     &             SQRT(AMDX*AMDX+AMDY*AMDY)
 65   FORMAT(/'STORM NAME: ',A32,
     &       /'  OBSERVED CENTER POSITION:     ',2F10.2,
     &       /'  MODEL CENTER POSITION :       ',2F10.2,
     &       /'  MODEL CENTER POSITION (TIM):  ',2F10.2,
     &       /'  RELOCATION DISTANCE (DEGREE): ',3F10.2)
        DO I=1,K1STM
          IF(STMNAME(I).EQ.ST_NAME(KST))THEN
            IF(ISTMCY1(I).EQ.0.and.ISTMCX1(I).EQ.0)THEN
               CLON_NEW=CLON_NHC
               CLAT_NEW=CLAT_NHC
            END IF
            WRITE(52,79)
     &      ISTMCY1(I),ISTMCX1(I),STMNAME(I)
 79         FORMAT(/'  TRACKER OUTPUT: ',2i4,5x,A3)
          END IF
        END DO
!      END IF

c test by qliu
c      MDX=MDX+50
c      AMDX=AMDX+50*DLN

      DO J=1,JMAX-1
        IF(CLAT_NHC.LT.GLAT(1,J).and.
     &         CLAT_NHC.GE.GLAT(1,J+1))THEN
          MNHC=J
          IF(CLAT_NHC.LT.0.5*(GLAT(1,J)+GLAT(1,J+1)))MNHC=J+1
          GO TO 566
        END IF
      END DO
 566  CONTINUE 
      DO J=1,JMAX-1
        IF(CLAT_NEW.LT.GLAT(1,J).and.
     &         CLAT_NEW.GE.GLAT(1,J+1))THEN
          MNEW=J
          IF(CLAT_NEW.LT.0.5*(GLAT(1,J)+GLAT(1,J+1)))MNEW=J+1
          GO TO 577
        END IF
      END DO  
 577  CONTINUE
      MDY=MNHC-MNEW
      PRINT*,'MDX,MDY,MNHC,MNEW=',MDX,MDY,MNHC,MNEW
      PRINT*,'AMDX,AMDY=',AMDX,AMDY
      PRINT*,'CLON_NHC,CLAT_NHC=',CLON_NHC,CLAT_NHC
      PRINT*,'CLON_NEW,CLAT_NEW=',CLON_NEW,CLAT_NEW
      RDIST2=AMDX*AMDX+AMDY*AMDY

      IF(NSEM.GE.1)RDIST2=max(0.021,RDIST2)

      IF(RDIST2.LE.0.02)THEN
        PRINT*,'   '
        PRINT*,' STORM NAME= ',ST_NAME(KST)
        PRINT*,' CENTER DISTANCE is less than 15 km',
     1  ', storm is not relocated'
        AMDX=0.
        AMDY=0.
        MDX=0
        MDY=0
c        IF(KST.NE.KSTM)THEN
c          DO I=1,113
c           READ(IUT1) DATG
c           WRITE(IUT2) DATG
c          END DO
c          GO TO 788
c        END IF
      ELSE
        PRINT*,'    '
        PRINT*,' STORM NAME= ',ST_NAME(KST)
        PRINT*,' Center Distance = ',SQRT(RDIST2),' Deg.',
     3  ', relocation starts ...... '

      END IF
c
      IB=0
C
      DO J=1,JMAX
      DO I=1,IMAX
C
      A = GLON(I,J) - CLON_NEW
      B = GLAT(I,J) - CLAT_NEW
      R = SQRT(A**2. + B**2.)
      IF(R.EQ.0.) GO TO 444
      TH = ACOS(A/R) / RAD
      IF(B.LT.0.) TH = 360-TH
C
      IF(TH.LE.7.5 .OR. TH.GT.352.5 ) IC = 1
      DO M2=2,24
        IF((TH.GT.(15.*(M2-1)-7.5)).and.
     &     (TH.LE.(15.*M2-7.5)))IC=M2
      END DO
C
      IF(R.LT.R0(IC)) THEN
      IB = IB+1
      ING(IB) = I
      JNG(IB) = J
      ENDIF
C
      GO TO 22
C
444   IB = IB+1
      ING(IB) = I
      JNG(IB) = J
22    CONTINUE
C
      ENDDO
      ENDDO
C
      CALL landcmsk(IMAX,JMAX,GLON,GLAT,ZDATG,IFLAG,lsflag,kst)

c temp relocation turned on
!      IFLAG = 1 

c Check if the syndata need to be called

c      print *,'GAUSSIAN GRID # WITHIN R0 ',IB
c      DO I = 1,IB
c      print *,'GAUSSIAN GRID WITHIN R0, LAT,LON ',
c     1      GLAT(ING(I),JNG(I)),GLON(ING(I),JNG(I))
c      print *,'GAUSSIAN GRID WITHIN R0 ',ING(I),JNG(I)
c      ENDDO

C.. SETTING VALUE for xvect, yvect, a(,), capd2

      call rodist

      call amatrix
c
c      REWIND IUT

      KMP=2*KMAX+1
      KDIV1=3+KMP
      KQ1=KDIV1+4*KMP

      NRED1 = 0

      IG = 0
      DO 777 IV = 1,MTV3

      IREM = -22
C
      CALL READ1(IUT,NRED1,MTV3,SKIP,PDAT)
C
      DO J=1,JX
      DO I=1,IX
        ENV1(I,J,IV) = SKIP(I,J)
      ENDDO
      ENDDO

      IF(IV.GT.KDIV1.AND.IV.LE.KQ1)IREM=MOD(IV-KDIV1,4)
      IF((IV.GE.3.AND.IV.LE.KDIV1).OR.(IV.GT.KQ1).OR.
     1     (IREM.EQ.1.OR.IREM.EQ.2)) THEN
      IG = IG+1
c      print *,'ORIGINAL VARIABLE # IS ',IV
c      print *,'VARIABLE # IS ',IG

c added by Qingfu Liu
c obtain the disturbance field

      DO J=1,JX
      DO I=1,IX
        U(I,J)=SKIP(I,J)
      END DO
      END DO
c
c First smooth in east-west direction
c
      DO 107 J=1,JX
      DO N=1,NF
      XTU(1,N)  = U(1,J)
      XTU(IX,N) = U(IX,J)
      ENDDO
C
      DO I=2,IX-1
      XTU(I,1) = U(I,J)+FK(1)*(U(I-1,J)+U(I+1,J)-2.*U(I,J))
      ENDDO
C
      DO N=2,NF
      DO I=2,IX-1
      XTU(I,N)=XTU(I,N-1)+FK(N)*(XTU(I-1,N-1)+XTU(I+1,N-1)-2.
     1         *XTU(I,N-1))
      ENDDO
      ENDDO
C
      DO I=1,IX
      US(I,J) = XTU(I,NF)
      ENDDO
C
 107  CONTINUE
C
C.. DO MERIDIONAL FILTER
C
      DO 207 I=1,IX
C
      DO N=1,NF
      YTU(1,N)  = US(I,1)
      YTU(JX,N) = US(I,JX)
      ENDDO
C
      DO J = 2 , JX-1
      YTU(J,1) = US(I,J) + FK(1)*(US(I,J-1) + US(I,J+1)
     *                          -2.*US(I,J))
      ENDDO
CC
      DO N = 2 , NF
      DO J = 2 , JX-1
      YTU(J,N) = YTU(J,N-1) + FK(N)*(YTU(J-1,N-1)  +
     *              YTU(J+1,N-1) - 2.*YTU(J,N-1))
      ENDDO
      ENDDO
C
      DO J = 1 , JX
      US(I,J)   =  YTU(J,NF)
      ENDDO
 207  CONTINUE
C
C.. GET THE DISTURBANCE FIELD
C
      DO I=1,IX
      DO J=1,JX
      DKY(I,J) = U(I,J) - US(I,J)
      ENDDO
      ENDDO

      DKM=DKY
      CALL SEPAR(DKY,DKM)
      
      DO J=1,JX                                                                 
      DO I=1,IX
        SKIP(I,J)=DKM(I,J)
c        SKIP(I,J)=U(I,J)
        DKY(I,J) = DKM(I,J) + US(I,J)
c        DKY(I,J) = U(I,J)
      ENDDO
      ENDDO

      DO J=1,JX
      DO I=1,IX
cnew        ENV1(I,J,IV) = DKY(I,J)
        ENV1(I,J,IV) = DKY(I,J)-PDAT(I,J,IV)
      ENDDO
      ENDDO

      ENDIF

 777  CONTINUE

      ENV=0.

      CALL P2SIG(KMAX,MTV2,MTV3,ENV(1,1,1),ENV1(1,1,1),
     &       PDAT(1,1,1),HDAT(1,1,1,KST),PSC_MX1,HSIG,HP,KST,
     &       nvcd,idvc,idsl,vcrd)
!      CALL P2SIG(KMAX,MTV2,MTV3,ENV(1,1,1),ENV1(1,1,1),
!     &           KST)

cnew    K=1,2 and the U,V field was doubled here, but never used later
      DO K=1,MTV2
      DO J=1,JX
      DO I=1,IX
        ENV(I,J,K)=ENV(I,J,K)+HDAT(I,J,K,KST)
      END DO
      END DO
      END DO 
cnew

      KDIV2=3+KMAX
      KQ2=KDIV2+4*KMAX

      IG = 0
      DO 781 IV = 1,MTV2

      IREM = -22
C
      IF(IV.GT.KDIV2.AND.IV.LE.KQ2)IREM=MOD(IV-KDIV2,4)
      IF((IV.GE.3.AND.IV.LE.KDIV2).OR.(IV.GT.KQ2).OR.
     1     (IREM.EQ.1.OR.IREM.EQ.2)) THEN
      IG = IG+1

      DO J=1,JX
      DO I=1,IX
        DKY(I,J)=ENV(I,J,IV)
      ENDDO
      ENDDO
      CALL GMOVE(NSEM,KST,MWAVE,KMAX,IKMAX,IMAX,JMAX,MAXWV2,MTV,MTV1,
     1          HDATA,SKIP2,DKY,IG,IFLAG,PSLB,ZDATG,GLON,GLAT,datao)

c      CALL GMOVE(KST,MWAVE,MAXWV2,MTV,MTV1,HDATA,SKIP2,DKY,
c     1          IG,IFLAG,PSLB)

      ENDIF

 781  CONTINUE

 788  CONTINUE

      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S1,
     &            HDATA(1,1,3),-1) 

      DO K=1,KMAX
        NCNT2 = NCNT2 + 1
        DO I=1,MAXWV2
          WORK_3(I)=WK_S1(I,K)
	  datao%t(i,k)=work_3(i)
        END DO
!        WRITE(KUNIT) (WORK_3(NW),NW=1,MAXWV2)
      END DO

      DO K=1,KMAX
      DO J=1,JMAX
      DO I=1,IMAX
        WK_G(I,J,K)=HDATA(I,J,KMAX+1+2*K)
      END DO
      END DO
      END DO

      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S1,
     &            WK_G,-1)

      DO K=1,KMAX
      DO J=1,JMAX
      DO I=1,IMAX
        WK_G(I,J,K)=HDATA(I,J,KMAX+2+2*K)
      END DO
      END DO
      END DO

      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S2,
     &            WK_G,-1)

      DO K=1,KMAX
        DO I=1,MAXWV2
          WORK_3(I)=WK_S1(I,K)
	  datao%d(i,k)=work_3(i)
        END DO
!        WRITE(KUNIT) (WORK_3(NW),NW=1,MAXWV2)
        DO I=1,MAXWV2
          WORK_3(I)=WK_S2(I,K)
	  datao%z(i,k)=work_3(i)
        END DO
!        WRITE(KUNIT) (WORK_3(NW),NW=1,MAXWV2)
cc        CALL G2SPC(HDATA(1,1,86+K))
      END DO

      CALL SPTEZM(0,MWAVE,4,IMAX,JMAX,KMAX,WK_S1,
     &            HDATA(1,1,3+3*KMAX),-1)

      DO K=1,KMAX
        DO I=1,MAXWV2
          WORK_3(I)=WK_S1(I,K)
	  datao%q(i,k,1)=work_3(i)
        END DO
!        WRITE(KUNIT) (WORK_3(NW),NW=1,MAXWV2)
      END DO
 
C
      DO K=1,KMAX
c        READ(20)SKIP2
c        READ(20)SKIP2  
cql        READ(20)
cql        READ(20)
        NCNT2 = NCNT2 + 2
      END DO
      DO K=1,KMAX
cql        READ(20)
         NCNT2 = NCNT2 + 1
c        READ(20)SKIP2
c        WRITE(KUNIT)(SKIP2(NW),NW=1,MAXWV2)                 
      END DO
      DO K=1,KMAX
cql        READ(20)(OZ(NW),NW=1,MAXWV2) 
cql        WRITE(KUNIT)(OZ(NW),NW=1,MAXWV2)                 
!        NCNT2 = NCNT2 +1
        NCNT2 = 4*KMAX+2+K
!        WRITE(KUNIT)(SKIP2(NW,NCNT2),NW=1,MAXWV2)
        do nw=1,maxwv2
	  datao%q(nw,k,2)=skip2(nw,ncnt2)
	enddo
 
      END DO

      DO K=1,IKMAX
        NCNT2 = NCNT2 +1
!        WRITE(KUNIT)(SKIP2(NW,NCNT2),NW=1,MAXWV2)
        do nw=1,maxwv2
	  datao%q(nw,k,3)=skip2(nw,ncnt2)
	enddo
      END DO

      DEALLOCATE ( WORK_3 )
      DEALLOCATE ( WK_S1, WK_S2, WK_G )

C
      RETURN
      END
C
      SUBROUTINE FIND_NEWCT(UD,VD)
      PARAMETER (IR=15,IT=24,IX=41,JX=41,ID=7,JD=7)
      DIMENSION TNMX(ID,JD),UD(IX,JX),VD(IX,JX)
      DIMENSION WTM(IR),R0(IT)
      COMMON /POSIT/CLON_NEW,CLAT_NEW,SLON,SLAT,CLON,CLAT,RAD                   
      COMMON /vect/R0,XVECT(IT),YVECT(IT)      
c      COMMON /CT/SLON,SLAT,CLON,CLAT,RAD
c      COMMON /GA/CLON_NEW,CLAT_NEW,R0
C
      PI=ASIN(1.)*2.
      RAD=PI/180.
C
      XLAT = CLAT-3.
      XLON = CLON-3.
c      print *,'STARTING LAT, LON AT FIND NEW CENTER ',XLAT,XLON
C
      DO I=1,ID
      DO J=1,JD
      TNMX(I,J) = 0.
      BLON = XLON + (I-1)
      BLAT = XLAT + (J-1)
C
C.. CALCULATE TANGENTIAL WIND EVERY 1 deg INTERVAL
C..  7*7 deg AROUND 1ST 1ST GUESS VORTEX CENTER
C
      DO 10 JL=1,IR
      WTS= 0.
      DO 20 IL=1,IT
      DR = JL
      DD = (IL-1)*15*RAD
      DLON = DR*COS(DD)
      DLAT = DR*SIN(DD)
      TLON = BLON + DLON
      TLAT = BLAT + DLAT
C.. INTERPOLATION U, V AT TLON,TLAT AND CLACULATE TANGENTIAL WIND
      IDX = IFIX(TLON) - SLON + 1
      IDY = IFIX(TLAT) - SLAT + 1
      DXX  = TLON - IFIX(TLON)
      DYY  = TLAT - IFIX(TLAT)
C
      X1 = UD(IDX  ,IDY+1)*DYY + UD(IDX  ,IDY)*(1-DYY)
      X2 = UD(IDX+1,IDY+1)*DYY + UD(IDX+1,IDY)*(1-DYY)
      Y1 = UD(IDX+1,IDY  )*DXX + UD(IDX,IDY  )*(1-DXX)
      Y2 = UD(IDX+1,IDY+1)*DXX + UD(IDX,IDY+1)*(1-DXX)
      UT = (X1*(1-DXX)+X2*DXX + Y1*(1-DYY)+Y2*DYY)/2.
      IF(IL.EQ.0.OR.IL.EQ.13) UT = Y1
      IF(IL.EQ.7.OR.IL.EQ.19) UT = X1
C
      X1 = VD(IDX  ,IDY+1)*DYY + VD(IDX  ,IDY)*(1-DYY)
      X2 = VD(IDX+1,IDY+1)*DYY + VD(IDX+1,IDY)*(1-DYY)
      Y1 = VD(IDX+1,IDY  )*DXX + VD(IDX,IDY  )*(1-DXX)
      Y2 = VD(IDX+1,IDY+1)*DXX + VD(IDX,IDY+1)*(1-DXX)
      VT = (X1*(1-DXX)+X2*DXX + Y1*(1-DYY)+Y2*DYY)/2.
      IF(IL.EQ.0.OR.IL.EQ.13) VT = Y1
      IF(IL.EQ.7.OR.IL.EQ.19) VT = X1
C.. TANGENTIAL WIND
      WT = -SIN(DD)*UT + COS(DD)*VT
      WTS = WTS+WT
20    CONTINUE
      WTM(JL) = WTS/24.
10    CONTINUE
C
C Southern Hemisphere
      IF(CLAT_NEW.LT.0)THEN
        DO JL=1,IR
          WTM(JL)=-WTM(JL)
        END DO
      END IF
C EnD SH

      TX = -10000000.
      DO KL = 1,IR
      IF(WTM(KL).GE.TX) THEN
      TX = WTM(KL)
      ENDIF
      ENDDO
C
      TNMX(I,J) = TX
      ENDDO
      ENDDO
C.. FIND NEW CENTER
      TTX = -1000000.
      DO I=1,ID
      DO J=1,JD
      IF(TNMX(I,J).GE.TTX) THEN
      TTX = TNMX(I,J)
      NIC = I
      NJC = J
      ENDIF
      ENDDO
      ENDDO
C
      CLAT_NEW = XLAT + (NJC-1)
      CLON_NEW = XLON + (NIC-1)
C
      print *,'NEW CENTER,  I, J IS   ',NIC,NJC
      print *,'NEW CENTER, LAT,LON IS ',CLAT_NEW,CLON_NEW
      print *,'MAX TAN. WIND AT NEW CENTER IS ',TTX
C
      RETURN
      END
C
      SUBROUTINE TWIND(UD,VD,TW)
C
      PARAMETER (IX=41,JX=41,NF=11,IT=24,IR=120)
      DIMENSION UD(IX,JX),VD(IX,JX),TW(IT,IR),R0(IT)
      COMMON /POSIT/CLON_NEW,CLAT_NEW,SLON,SLAT,CLON,CLAT,RAD                   
      COMMON /vect/R0,XVECT(IT),YVECT(IT)      
c      COMMON /CT/SLON,SLAT,CLON,CLAT,RAD
c      COMMON /GA/CLON_NEW,CLAT_NEW,R0
C
      DO J=1,IR
      DO I=1,IT
C.. DETERMINE LAT, LON AREOUND CIRCLE
      DR = 0.1*J
      DD = (I-1)*15.*RAD
      DLON = DR*COS(DD)
      DLAT = DR*SIN(DD)
      TLON = CLON_NEW + DLON
      TLAT = CLAT_NEW + DLAT
C.. INTERPOLATION U, V AT TLON,TLAT AND CLACULATE TANGENTIAL WIND
      IDX = IFIX(TLON) - SLON + 1
      IDY = IFIX(TLAT) - SLAT + 1
      DXX  = TLON - IFIX(TLON)
      DYY  = TLAT - IFIX(TLAT)
C
      X1 = UD(IDX  ,IDY+1)*DYY + UD(IDX  ,IDY)*(1-DYY)
      X2 = UD(IDX+1,IDY+1)*DYY + UD(IDX+1,IDY)*(1-DYY)
      Y1 = UD(IDX+1,IDY  )*DXX + UD(IDX,IDY  )*(1-DXX)
      Y2 = UD(IDX+1,IDY+1)*DXX + UD(IDX,IDY+1)*(1-DXX)
      UT = (X1*(1-DXX)+X2*DXX + Y1*(1-DYY)+Y2*DYY)/2.
      IF(I.EQ.0.OR.I.EQ.13) UT = Y1
      IF(I.EQ.7.OR.I.EQ.19) UT = X1
C
      X1 = VD(IDX  ,IDY+1)*DYY + VD(IDX  ,IDY)*(1-DYY)
      X2 = VD(IDX+1,IDY+1)*DYY + VD(IDX+1,IDY)*(1-DYY)
      Y1 = VD(IDX+1,IDY  )*DXX + VD(IDX,IDY  )*(1-DXX)
      Y2 = VD(IDX+1,IDY+1)*DXX + VD(IDX,IDY+1)*(1-DXX)
      VT = (X1*(1-DXX)+X2*DXX + Y1*(1-DYY)+Y2*DYY)/2.
      IF(I.EQ.0.OR.I.EQ.13) VT = Y1
      IF(I.EQ.7.OR.I.EQ.19) VT = X1
C.. TANGENTIAL WIND
      TW(I,J) = -SIN(DD)*UT + COS(DD)*VT
C
      ENDDO
      ENDDO
C SH
      IF(CLAT_NEW.LT.0)THEN
        DO J=1,IR
        DO I=1,IT
          TW(I,J)=-TW(I,J)
        ENDDO
        ENDDO
      END IF
C End SH
C
      RETURN
      END
C
      SUBROUTINE STRT_PT(RMX,TW,RFAVG)
C
      PARAMETER (IX=41,JX=41,NF=11,IT=24,IR=120)
      DIMENSION TW(IT,IR),TWM(IR),TMXX(IT),RMX(IT)
      REAL JMX
C
      DO I=1,IR
      TWM(I) = 0.
      ENDDO
C
C.. CALCULATE MEAN TANGENTIAL WIND
C
      DO 10 J=1,IR
      TM=0.
      DO 20 I=1,IT
      TM = TM + TW(I,J)
20    CONTINUE 
      TWM(J) = TM/24.
c      print *,'MEAN TANGENTIAL WIND ',J,TWM(J)
10    CONTINUE
C
C.. FIND MAXIMUM TANGENTIAL WIND RADIUS
C
      TMX=-100000000000.
      DO J=1,IR
      IF(TWM(J).GE.TMX) THEN
      TMX=TWM(J)
      JMX = J*0.1
      ENDIF
      ENDDO
C
      print *,'MAXIMUM TANGENTIAL WIND RADIUS ',JMX
      JJ=IFIX(JMX*10.)
      print *,'MAXIMUM TANGENTIAL WIND SPEED  ',TWM(JJ)
C
      JXX = 15 * JMX
c      print *,'JXX, 15*JMX is ',JXX
C
      ICK = 1
      CNT = 0.000004 
c      print *,'CNT  ',CNT
C
      DO 30 K=JXX,120
      IF(TWM(K).GE.6..OR.TWM(K).LT.3.) GO TO 30
      DXX = 10000.
      DV = TWM(K) - TWM(K+1)
      DVDR = DV/DXX
      IF(DVDR.LT.CNT) ICK = ICK+1
      IF(ICK.EQ.3) THEN
      RF=K*0.1
      GO TO 40
      ENDIF
30    CONTINUE
C
40    CONTINUE
      IF(ICK.NE.3) THEN
      DO IK=JXX,120     
      IF(TWM(IK).LE.3) THEN
      RF = IK*0.1
      ICK=3
      GO TO 50
      ENDIF
      ENDDO
      ENDIF 
C
50    CONTINUE
      IF(ICK.NE.3) RF = 12.
C
      RFAVG = RF
c
C.. CALCULATE Ra, Rb..  REF. KURIHARA ET AL. 1995
C
      RA = IFIX((0.5 * JMX)*10.)/10.
      RB = IFIX((0.75 * JMX + 0.25 * RF)*10.)/10.
      IRA = IFIX(RA*10.+0.5)
      IRB = IFIX(RB*10.+0.5)
C
c      print *,'Ra, Rb, Rf  ', RA,RB,RF
C
C.. DETERMINE STARTING POINT FOR EVERY 24 DIRECTION
C
      DO I=1,IT
      TMXX(I) = -100000000.
      DO J=1,IR
      IF(TW(I,J).GE.TMXX(I)) THEN
      TMXX(I) = TW(I,J)
      RMX(I) = J*0.1*1.1
      ENDIF
      ENDDO
      ENDDO
C
c      DO I=1,IT
c      print *,'I, MX TANGENTIAL WIND RADIUS ',I,RMX(I),TMXX(I)
c      ENDDO
C
      DO I=1,IT
      IF (RMX(I).GT.RB.OR.RMX(I).LT.RA) THEN
      TMX = -10000000.
      DO KK=IRA,IRB
      IF(TW(I,KK).GE.TMX) RM = KK * 0.1 * 1.1
      ENDDO
      MR = IFIX(RM*10. + 0.5)
      ICL=0
      DO LL = MR,IRB
      IF(TW(I,LL).LT.0.) ICL=ICL+1
      ENDDO
      IF(ICL.EQ.0) RMX(I) = RM*1.1
      ENDIF
      ENDDO
C
c      DO I=1,IT
c      print *,'I, RST ',I,RMX(I)
c      ENDDO
C
      RETURN
      END
C 
      SUBROUTINE FILTER(RS,TW,RF,RFAVG)
      PARAMETER (IX=41,JX=41,IT=24,IR=120)
C
      DIMENSION RS(IT),TW(IT,IR),RF(IT),R0(IT),IST(IT)
      COMMON /vect/R0,XVECT(IT),YVECT(IT)      
c      COMMON /GA/CLON_NEW,CLAT_NEW,R0
C
      ICK = 1
      CNT = 0.000004 
c      print *,'CNT  ',CNT
C
      DO I=1,IT
      IST(I) = IFIX(RS(I)*10)      
c      print *,'STARTING POINT ',I,IST(I)
      ENDDO
C
      DO 100 I=1,IT
      IS = IST(I)
C
      DO 30 K=IS,IR 
      IF(TW(I,K).GE.6..OR.TW(I,K).LT.3.) GO TO 30
      DXX = 10000.
      DV = TW(I,K) - TW(I,K+1)
      DVDR = DV/DXX
      IF(DVDR.LT.CNT) THEN
      ICK = ICK+1
      ENDIF
      IF(ICK.EQ.3) THEN
      RF(I)=K*0.1 + 0.0000001
c      print *,'1st Catagory ',I
      GO TO 100
      ENDIF
30    CONTINUE
C
40    CONTINUE
      DO IK=IS,IR
      IF(TW(I,IK).LE.3) THEN
      RF(I) = IK*0.1 + 0.00000001
c      print *,'2nd Catagory ',I
      GO TO 100
      ENDIF
      ENDDO
C
50    CONTINUE
c      print *,'3rd Catagory ',I
      RF(I) = 12.
100   CONTINUE
C
c      RMAX=0.
      DO I=1,IT
      R0(I) = 1.25 * RF(I)
!! NEW
      IF(R0(I).LT.2.0)R0(I)=2.0
c      IF(RMAX.LT.R0(I))RMAX=R0(I)
c      print *,'R0,Rf AT EACH DIRECTION ',I,R0(I),RF(I)
      ENDDO
C test for circular domain
c      DO I=1,IT
c         R0(I)=RMAX
cc        R0(I) = RFAVG*1.25
c      print *,'R0,Rf AT EACH DIRECTION ',I,R0(I),RF(I)
c      ENDDO
C
      RETURN 
      END
C
      SUBROUTINE GMOVE(NSEM,KST,MWAVE,KMAX,IKMAX,IGU,JGU,MAXWV2,MTV,
     1    MTV1,HDATA,SKIP2,DM1,IS1,IFLAG,PSLB,ZDATG,GLON,GLAT,datao)

c      SUBROUTINE GMOVE(KST,MWAVE,MAXWV2,MTV,MTV1,HDATA,SKIP2,DM1,
c     1                IS1,IFLAG,PSLB)

      use sigio_module
      use sigio_r_module

      type(sigio_data) datao

c      PARAMETER (IX=41,JX=41,IGU=384,JGU=190)
      PARAMETER (IX=41,JX=41)
      PARAMETER (IT=24,NSG=8000)
C
      DIMENSION DMM(IX,JX),DATG(IGU,JGU),DDAT(IGU,JGU)
      DIMENSION ZDATG(IGU,JGU),DM1(IX,JX),T1(IGU,JGU),PSL(IGU,JGU)
      DIMENSION R0(IT),GLAT(IGU,JGU),GLON(IGU,JGU),ING(NSG),JNG(NSG)
      DIMENSION ALAT(JX),ALON(IX)
      COMMON /POSIT/CLON_NEW,CLAT_NEW,SLON,SLAT,CLON,CLAT,RAD
      COMMON /vect/R0,XVECT(IT),YVECT(IT)      
      COMMON /ST/ALON,ALAT
      COMMON /NHC2/MDX,MDY
      COMMON /NHC3/AMDX,AMDY
      COMMON /CHNL/IUT,KSTM
c      COMMON /CT/SLON,SLAT,CLON,CLAT,RAD
c      COMMON /GA/CLON_NEW,CLAT_NEW,R0
      COMMON /TR/ING,JNG,IB
c      COMMON /TR/ZDATG,GLON,GLAT,ING,JNG,IB

      COMMON /HDAT3/NWRT2,NRED2
      REAL HDATA(IGU,JGU,MTV)
      REAL PSLB(IGU,JGU)
      COMMON /CHEN/KUNIT,ITIM

      DIMENSION DATG2(IGU,JGU)
      REAL(4) SKIP2(MAXWV2,MTV1+IKMAX)

      COMMON /COEF5/NCNT,NCNT2

C
C.. SETTING BASIC VARIABLES FOR INTERPOLATING GAUSSIAN GRID
C

      ISE = IS1
      DO I=1,IX
      DO J=1,JX
      DMM(I,J) = DM1(I,J)
      ENDDO
      ENDDO
C
C.. INTERPOLATE TO GAUSSIAN GRID
C
      CALL READ2(IGU,JGU,NRED2,MTV,DATG,HDATA)
c
      DO I=1,IGU
      DO J=1,JGU
        DATG2(I,J)=DATG(I,J)
        DDAT(I,J)=0.
      ENDDO
      ENDDO
C
      RDIST2=AMDX*AMDX+AMDY*AMDY

      IF(NSEM.GE.1)RDIST2=max(0.021,RDIST2)

      IF(RDIST2.GT.0.02)THEN
cc test
      DO I = 1,IB
      IW = ING(I)
      JW = JNG(I)

c      DO IW = 1, IGU
c      DO JW = 1, JGU
      HLA = GLAT(IW,JW)
      HLO = GLON(IW,JW)
C
      DO II=1,IX-1
       IF(HLO.GT.ALON(II).and.HLO.LE.ALON(II+1))THEN
        DO JJ=1,JX-1
        IF(HLA.GT.ALAT(JJ).and.HLA.LE.ALAT(JJ+1))THEN
          LX=II
          LY=JJ

         DXX = HLO-ALON(LX)
         DYY = HLA-ALAT(LY)
C
         X1 = DMM(LX  ,LY+1)*DYY + DMM(LX  ,LY  )*(1-DYY)
         X2 = DMM(LX+1,LY+1)*DYY + DMM(LX+1,LY  )*(1-DYY)
         Y1 = DMM(LX+1,LY  )*DXX + DMM(LX  ,LY  )*(1-DXX)
         Y2 = DMM(LX+1,LY+1)*DXX + DMM(LX  ,LY+1)*(1-DXX)
         DATG(IW,JW)=(X1*(1-DXX)+X2*DXX + Y1*(1-DYY)+Y2*DYY)/2.

         IF(ISE.GE.2) DDAT(IW,JW)=DATG2(IW,JW)-DATG(IW,JW)
         GO TO 555

        END IF
        END DO
       END IF
      END DO  
 555   CONTINUE
c      ENDDO
c      ENDDO
      ENDDO
      END IF
c end test

      IF(ISE.EQ.1) THEN
c
c        READ(70) PSL
        PSL=PSLB

        DO I = 1,IB
          IW = ING(I)
          JW = JNG(I)
          DDAT(IW,JW)=PSL(IW,JW)-DATG(IW,JW)
          PSL(IW,JW)=DATG(IW,JW)
        END DO
c
c Move vortex

cc        DO I = 1,IB
cc          IW = ING(I)
cc          JW = JNG(I)
cc          IWX=IW+MDX
cc          JWY=JW+MDY
cc          IF(IWX.GT.IGU)IWX=IWX-IGU
cc          IF(IWX.LT.1)IWX=IWX+IGU
CQLIUC
cc          PSL(IWX,JWY) = PSL(IWX,JWY)+DDAT(IW,JW)
cc        ENDDO

        CALL MOVETX(NSEM,ISE,KST,IGU,JGU,GLON,GLAT,PSL,DDAT,ZDATG)

        PSLB = PSL

        CALL WRIT2(IGU,JGU,NWRT2,MTV,PSL,HDATA)
c
      ELSEIF(ISE.EQ.2) THEN
cyc   REWIND 36
cyc   READ(36) PSL 
       PSL = PSLB
       IF(IFLAG.EQ.1)THEN
        DO I=1,IGU
        DO J=1,JGU
         T1(I,J) = DATG2(I,J)
        ENDDO
        ENDDO
       ELSE
        DO I=1,IGU
        DO J=1,JGU
         T1(I,J) = DATG(I,J)
        ENDDO
        ENDDO
       END IF
        IF(KST.EQ.KSTM)THEN
          CALL SLP2SP(IGU,JGU,ZDATG,KUNIT,MWAVE,T1,PSL,datao)
        END IF
      END IF

c temperature field
c qliu    
       
      IF(ISE.GE.2.and.ISE.LE.(KMAX+1))then

        IF(IFLAG.EQ.1)THEN
cold          IF(KST.EQ.KSTM) THEN
cql            READ(20)SKIP2
cold            NCNT2 = NCNT2 + 1
cold            WRITE(KUNIT)(SKIP2(NW,NCNT2),NW=1,MAXWV2)
cold          END IF
                                                                                                                              
          DDAT=0.
          CALL MOVETX(NSEM,ISE,KST,IGU,JGU,GLON,GLAT,DATG2,DDAT,ZDATG)
          CALL WRIT2(IGU,JGU,NWRT2,MTV,DATG2,HDATA)

        ELSE

c Move vortex
cc          DO I = 1,IB
cc            IW = ING(I)
cc            JW = JNG(I)
cc            IWX=IW+MDX
cc            JWY=JW+MDY
cc            IF(IWX.GT.IGU)IWX=IWX-IGU
cc            IF(IWX.LT.1)IWX=IWX+IGU
CQLIUC
cc            DATG(IWX,JWY) = DATG(IWX,JWY)+DDAT(IW,JW)
cc          ENDDO

          CALL MOVETX(NSEM,ISE,KST,IGU,JGU,GLON,GLAT,DATG,DDAT,ZDATG)

cnew          IF(KST.EQ.KSTM) THEN
cql            READ(20)SKIP2
cnew            NCNT2 = NCNT2 + 1
cnew            CALL G2SPC(DATG)
cnew          END IF

          CALL WRIT2(IGU,JGU,NWRT2,MTV,DATG,HDATA)

        END IF
      END IF
C
      IF(ISE.GT.(KMAX+1).and.ISE.LE.(3*KMAX+1))THEN
c Move vortex

cc        DO I = 1,IB
cc          IW = ING(I)
cc          JW = JNG(I)
cc          IWX=IW+MDX
cc          JWY=JW+MDY
cc          IF(IWX.GT.IGU)IWX=IWX-IGU
cc          IF(IWX.LT.1)IWX=IWX+IGU 
CQLIUC
cc          DATG(IWX,JWY) = DATG(IWX,JWY)+DDAT(IW,JW)
cc        ENDDO

         CALL MOVETX(NSEM,ISE,KST,IGU,JGU,GLON,GLAT,DATG,DDAT,ZDATG)
C
cnew        IF(KST.EQ.KSTM) THEN
cnew          CALL G2SPC(DATG)
cnew        END IF

        CALL WRIT2(IGU,JGU,NWRT2,MTV,DATG,HDATA)

      ENDIF

      IF(ISE.GT.(3*KMAX+1))THEN

        IF(IFLAG.EQ.1)THEN
cold          IF(KST.EQ.KSTM) THEN
cold            CALL G2SPC(KUNIT,MWAVE,IGU,JGU,DATG2)
cold          END IF
 
          DDAT=0.
          CALL MOVETX(NSEM,ISE,KST,IGU,JGU,GLON,GLAT,DATG2,DDAT,ZDATG)
          CALL WRIT2(IGU,JGU,NWRT2,MTV,DATG2,HDATA)
        ELSE

c Move vortex
cc          DO I = 1,IB
cc            IW = ING(I)
cc            JW = JNG(I)
cc            IWX=IW+MDX
cc            JWY=JW+MDY
cc            IF(IWX.GT.IGU)IWX=IWX-IGU
cc            IF(IWX.LT.1)IWX=IWX+IGU
CQLIUC
cc            DATG(IWX,JWY) = DATG(IWX,JWY)+DDAT(IW,JW)
cc          ENDDO

           CALL MOVETX(NSEM,ISE,KST,IGU,JGU,GLON,GLAT,DATG,DDAT,ZDATG)

cnew          IF(KST.EQ.KSTM) THEN
cnew            CALL G2SPC(DATG)
cnew          END IF

          CALL WRIT2(IGU,JGU,NWRT2,MTV,DATG,HDATA)

        END IF
      ENDIF

C
      RETURN
      END
C
      SUBROUTINE SLP2SP(IGU,JGU,ZDATG,KUNIT,MWAVE,T1,PSL,datao)

      use sigio_module
      use sigio_r_module

      type(sigio_data) datao

c      PARAMETER (IGU=384,JGU=190)
C
      DIMENSION T1(IGU,JGU),PSL(IGU,JGU)
      DIMENSION ZDATG(IGU,JGU)
c      COMMON /TR/ZDATG,GLON,GLAT,ING,JNG,IB
C
C.. MAKE SFC PRESSURE FROM MSLP
C
      G = 9.8
      R = 287.05
      GAMMA = 6.7*0.001
C
      DO JH=1,JGU
      DO IH=1,IGU
      PMSL = ALOG(PSL(IH,JH))
      A = (GAMMA * ZDATG(IH,JH)) / T1(IH,JH)
      B = ALOG(1+A)
      C = (G*B)/(R*GAMMA)
      DD = PMSL - C
      D1 = EXP(DD)/1000.
c      IF (D1.LE.10.) PRINT*,'SP is Less than 100mb at ',IH,JH,D1
      PSL(IH,JH) = ALOG(D1)
      ENDDO
      ENDDO
C
C.. GAUSSIAN GRID TO SPECTRAL COEFFEICENT
C
      call maxmin(psl,igu*jgu,1,1,1,'global SLP at SLP after int')
      CALL G2SPC(KUNIT,MWAVE,IGU,JGU,PSL,datao)
      call maxmin(t1,igu*jgu,1,1,1,'global T1 at SLP after int')
c      CALL G2SPC(KUNIT,T1)
C
      RETURN
      END
C
      SUBROUTINE G2SPC(KUNIT,MWAVE,IMAX,JMAX,Q1,datao)

      use sigio_module
      use sigio_r_module

      type(sigio_data) datao

C
c      PARAMETER ( IMAX= 384,JMAX= 190 )
C
      REAL Q1(IMAX,JMAX)

      REAL,   ALLOCATABLE :: DN(:)
      REAL(4),ALLOCATABLE :: WORK_3(:)

      MAXWV2=(MWAVE+1)*(MWAVE+2)
      MAXWV22=MAXWV2+1

      ALLOCATE ( DN(MAXWV22) )
      ALLOCATE ( WORK_3(MAXWV2) )
C
c      call maxmin(dn,MAXWV2,1,1,1,'surface pressure after making')

       call SPTEZ(0,MWAVE,4,IMAX,JMAX,DN,Q1,-1)

      DO I=1,MAXWV2
        WORK_3(I)=DN(I)
	datao%ps(i)=work_3(i)
      END DO
!      WRITE(KUNIT) (WORK_3(NW),NW=1,MAXWV2)

      DEALLOCATE (DN)
      DEALLOCATE (WORK_3)

      RETURN
      END
          subroutine srangel(var,n,label,level)
c print level, label, range, mean, avg dev, std dev, skew, n of zeroes
          dimension var(n)
          character*(*) label
          ptsn=n
          sa=0.0
          dmin=1.e40
          dmax=-1.e40
          nzero=0
          do j=1,n
            sa=sa+var(j)
            dmin=min(dmin,var(j))
            dmax=max(dmax,var(j))
            if (var(j) .eq. 0.0) then
              nzero=nzero+1
            endif
          enddo
          avg=sa/ptsn
          sl=0.0
          sv=0.0
          do j=1,n
            sl=sl+abs(var(j)-avg)
            sv=sv+(var(j)-avg)**2
          enddo
          adev=sl/ptsn
          sdev=sqrt(sv/(ptsn-1))
          if (sdev.gt.0.0) then
            ss=0.0
            do j=1,n
              devn=(var(j)-avg)/sdev
              ss=ss+devn**3
            enddo
            skew=ss/ptsn
          else
            skew=0.0
          endif
          if (level .eq. 0) then
            print *,label,dmin,dmax,avg,adev,sdev,skew,nzero
          else
            print *,level,label,dmin,dmax,avg,adev,sdev,skew,nzero
          endif
          return
          end

