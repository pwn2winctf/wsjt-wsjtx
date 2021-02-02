module q65_decode

  type :: q65_decoder
     procedure(q65_decode_callback), pointer :: callback
   contains
     procedure :: decode
  end type q65_decoder

  abstract interface
     subroutine q65_decode_callback (this,nutc,snr1,nsnr,dt,freq,    &
          decoded,idec,nused,ntrperiod)
       import q65_decoder
       implicit none
       class(q65_decoder), intent(inout) :: this
       integer, intent(in) :: nutc
       real, intent(in) :: snr1
       integer, intent(in) :: nsnr
       real, intent(in) :: dt
       real, intent(in) :: freq
       character(len=37), intent(in) :: decoded
       integer, intent(in) :: idec
       integer, intent(in) :: nused
       integer, intent(in) :: ntrperiod
     end subroutine q65_decode_callback
  end interface

contains

  subroutine decode(this,callback,iwave,nutc,ntrperiod,nsubmode,nfqso,   &
       ntol,ndepth,nfa0,nfb0,lclearave,single_decode,lagain,lnewdat0,    &
       emedelay,mycall,hiscall,hisgrid,nQSOprogress,ncontest,lapcqonly,navg0)

! Top-level routine that organizes the decoding of Q65 signals
! Input:  iwave            Raw data, i*2
!         nutc             UTC for time-tagging the decode
!         ntrperiod        T/R sequence length (s)
!         nsubmode         Tone-spacing indicator, 0-4 for A-E
!         nfqso            Target signal frequency (Hz)
!         ntol             Search range around nfqso (Hz)
!         ndepth           Optional decoding level
!         lclearave        Flag to clear the message-averaging arrays
!         emedelay         Sync search extended to cover EME delays
!         nQSOprogress     Auto-sequencing state for the present QSO
!         ncontest         Supported contest type
!         lapcqonly        Flag to use AP only for CQ calls
! Output: sent to the callback routine for display to user

    use timer_module, only: timer
    use packjt77
    use, intrinsic :: iso_c_binding
    use q65                               !Shared variables
    use prog_args
 
    parameter (NMAX=300*12000)            !Max TRperiod is 300 s
    class(q65_decoder), intent(inout) :: this
    procedure(q65_decode_callback) :: callback
    character(len=12) :: mycall, hiscall  !Used for AP decoding
    character(len=6) :: hisgrid
    character*37 decoded                  !Decoded message
    character*77 c77
    character*78 c78
    character*6 cutc
    character c6*6,c4*4,cmode*4
    character*80 fmt
    integer*2 iwave(NMAX)                 !Raw data
    real, allocatable :: dd(:)            !Raw data
    integer dat4(13)                      !Decoded message as 12 6-bit integers
    integer dgen(13)
    logical lclearave,lnewdat0,lapcqonly,unpk77_success
    logical single_decode,lagain
    complex, allocatable :: c00(:)        !Analytic signal, 6000 Sa/s
    complex, allocatable :: c0(:)         !Analytic signal, 6000 Sa/s

! Start by setting some parameters and allocating storage for large arrays
    call sec0(0,tdecode)
    nfa=nfa0
    nfb=nfb0
    lnewdat=lnewdat0
    idec=-1
    idf=0
    idt=0
    irc=0
    mode_q65=2**nsubmode
    npts=ntrperiod*12000
    nfft1=ntrperiod*12000
    nfft2=ntrperiod*6000

! Determine the T/R sequence: iseq=0 (even), or iseq=1 (odd)
    n=nutc
    if(ntrperiod.ge.60) n=100*n
    write(cutc,'(i6.6)') n
    read(cutc,'(3i2)') ih,im,is
    nsec=3600*ih + 60*im + is
    iseq=mod(nsec/ntrperiod,2)

    if(lclearave) call q65_clravg
    allocate(dd(npts))
    allocate (c00(0:nfft1-1))
    allocate (c0(0:nfft1-1))

    if(ntrperiod.eq.15) then
       nsps=1800
    else if(ntrperiod.eq.30) then
       nsps=3600
    else if(ntrperiod.eq.60) then
       nsps=7200
    else if(ntrperiod.eq.120) then
       nsps=16000
    else if(ntrperiod.eq.300) then
       nsps=41472
    else
       stop 'Invalid TR period'
    endif

    baud=12000.0/nsps
    this%callback => callback
    nFadingModel=1
    ibwa=max(1,int(1.8*log(baud*mode_q65)) + 1)
    ibwb=min(10,ibwa+3)
    if(iand(ndepth,3).ge.2) then
       ibwa=max(1,int(1.8*log(baud*mode_q65)) + 2)
       ibwb=min(10,ibwa+5)
    else if(iand(ndepth,3).eq.3) then
       ibwa=max(1,ibwa-1)
       ibwb=min(10,ibwb+1)
    endif
    
! Generate codewords for full-AP list decoding    
    call q65_set_list(mycall,hiscall,hisgrid,codewords,ncw) 
    dgen=0
    call q65_enc(dgen,codewords)         !Initialize the Q65 codec

    nused=1
    iavg=0
    call timer('q65_dec0',0)
! Call top-level routine in q65 module: establish sync and try for a q3 decode.
    call q65_dec0(iavg,nutc,iwave,ntrperiod,nfqso,ntol,ndepth,lclearave,  &
         emedelay,xdt,f0,snr1,width,dat4,snr2,idec)
!    idec=-1   !### TEMPORARY ###
    call timer('q65_dec0',1)

    if(idec.ge.0) then
       dtdec=xdt                        !We have a list-decode result at nfqso
       f0dec=f0
       go to 100
    endif

! Prepare for a single-period decode with iaptype = 0, 1, 2, or 4
    jpk0=(xdt+1.0)*6000                      !Index of nominal start of signal
    if(ntrperiod.le.30) jpk0=(xdt+0.5)*6000  !For shortest sequences
    if(jpk0.lt.0) jpk0=0
    call ana64(iwave,npts,c00)          !Convert to complex c00() at 6000 Sa/s
    call ft8apset(mycall,hiscall,ncontest,apsym0,aph10) ! Generate ap symbols
    where(apsym0.eq.-1) apsym0=0

    npasses=2
    if(nQSOprogress.eq.5) npasses=3
    if(lapcqonly) npasses=1
    iaptype=0
    do ipass=0,npasses                  !Loop over AP passes
       apmask=0                         !Try first with no AP information
       apsymbols=0
       if(ipass.ge.1) then
          ! Subsequent passes use AP information appropiate for nQSOprogress
          call q65_ap(nQSOprogress,ipass,ncontest,lapcqonly,iaptype,   &
               apsym0,apmask1,apsymbols1)
          write(c78,1050) apmask1
1050      format(78i1)
          read(c78,1060) apmask
1060      format(13b6.6)
          write(c78,1050) apsymbols1
          read(c78,1060) apsymbols
       endif

       call timer('q65loops',0)
       call q65_loops(c00,npts/2,nsps/2,nsubmode,ndepth,jpk0,   &
            xdt,f0,iaptype,xdt1,f1,snr2,dat4,idec)
!       idec=-1   !### TEMPORARY ###
       call timer('q65loops',1)
       if(idec.ge.0) then
          dtdec=xdt1
          f0dec=f1
          go to 100       !Successful decode, we're done
       endif
    enddo  ! ipass

    if(iand(ndepth,16).eq.0 .or. navg(iseq).lt.2) go to 100
! There was no single-transmission decode. Try for an average 'q3n' decode.
    call timer('list_avg',0)
! Call top-level routine in q65 module: establish sync and try for a q3
! decode, this time using the cumulative 's1a' symbol spectra.
    iavg=1
    call q65_dec0(iavg,nutc,iwave,ntrperiod,nfqso,ntol,ndepth,lclearave,  &
         emedelay,xdt,f0,snr1,width,dat4,snr2,idec)
    call timer('list_avg',1)
    if(idec.ge.0) then
       dtdec=xdt               !We have a list-decode result from averaged data
       f0dec=f0
       nused=navg(iseq)
       go to 100
    endif

! There was no 'q3n' decode.  Try for a 'q[0124]n' decode.
! Call top-level routine in q65 module: establish sync and try for a q[012]n
! decode, this time using the cumulative 's1a' symbol spectra.

    call timer('q65_avg ',0)
    iavg=2
    call q65_dec0(iavg,nutc,iwave,ntrperiod,nfqso,ntol,ndepth,lclearave,  &
         emedelay,xdt,f0,snr1,width,dat4,snr2,idec)
    call timer('q65_avg ',1)
    if(idec.ge.0) then
       dtdec=xdt                          !We have a q[012]n result
       f0dec=f0
       nused=navg(iseq)
    endif

100 decoded='                                     '
    if(idec.ge.0) then
! idec Meaning
! ------------------------------------------------------
! -1:  No decode
!  0:  Decode without AP information
!  1:  Decode with AP for "CQ        ?   ?"
!  2:  Decode with AP for "MyCall    ?   ?"
!  3:  Decode with AP for "MyCall DxCall ?"

! Unpack decoded message for display to user
       write(c77,1000) dat4(1:12),dat4(13)/2
1000   format(12b6.6,b5.5)
       call unpack77(c77,0,decoded,unpk77_success) !Unpack to get msgsent
       nsnr=nint(snr2)
       call this%callback(nutc,snr1,nsnr,dtdec,f0dec,decoded,    &
            idec,nused,ntrperiod)
       if(iand(ndepth,128).ne.0) call q65_clravg    !AutoClrAvg after decode
       call sec0(1,tdecode)
       open(22,file=trim(data_dir)//'/q65_decodes.dat',status='unknown',     &
            position='append',iostat=ios)
       if(ios.eq.0) then
! Save decoding parameters to q65_decoded.dat, for later analysis.
          write(cmode,'(i3)') ntrperiod
          cmode(4:4)=char(ichar('A')+nsubmode)
          c6=hiscall(1:6)
          if(c6.eq.'      ') c6='<b>   '
          c4=hisgrid(1:4)
          if(c4.eq.'    ') c4='<b> '
          fmt='(i6.4,1x,a4,5i2,3i3,f6.2,f7.1,f7.2,f6.1,f6.2,'//   &
               '1x,a6,1x,a6,1x,a4,1x,a)'
          if(ntrperiod.le.30) fmt(5:5)='6'
          write(22,fmt) nutc,cmode,nQSOprogress,idec,idf,idt,ibw,nused,    &
               icand,ncand,xdt,f0,snr1,snr2,tdecode,mycall(1:6),c6,c4,     &
               trim(decoded)
          close(22)
       endif
    else
! Report snr1, even if no decode.
       nsnr=db(snr1) - 35.0
       if(nsnr.lt.-35) nsnr=-35
       idec=-1
       call this%callback(nutc,snr1,nsnr,xdt,f0,decoded,                  &
            idec,0,ntrperiod)
    endif
    navg0=1000*navg(0) + navg(1)
    if(single_decode .or. lagain) go to 900

    do icand=1,ncand
! Prepare for single-period candidate decodes with iaptype = 0, 1, 2, or 4
       snr1=candidates(icand,1)
       xdt= candidates(icand,2)
       f0 = candidates(icand,3)
       jpk0=(xdt+1.0)*6000                   !Index of nominal start of signal
       if(ntrperiod.le.30) jpk0=(xdt+0.5)*6000  !For shortest sequences
       if(jpk0.lt.0) jpk0=0
       call ana64(iwave,npts,c00)       !Convert to complex c00() at 6000 Sa/s
       call ft8apset(mycall,hiscall,ncontest,apsym0,aph10) ! Generate ap symbols
       where(apsym0.eq.-1) apsym0=0

       npasses=2
       if(nQSOprogress.eq.5) npasses=3
       if(lapcqonly) npasses=1
       iaptype=0
       do ipass=0,npasses                  !Loop over AP passes
          apmask=0                         !Try first with no AP information
          apsymbols=0
          if(ipass.ge.1) then
          ! Subsequent passes use AP information appropiate for nQSOprogress
             call q65_ap(nQSOprogress,ipass,ncontest,lapcqonly,iaptype,   &
                  apsym0,apmask1,apsymbols1)
             write(c78,1050) apmask1
             read(c78,1060) apmask
             write(c78,1050) apsymbols1
             read(c78,1060) apsymbols
          endif

          call timer('q65loops',0)
          call q65_loops(c00,npts/2,nsps/2,nsubmode,ndepth,jpk0,   &
               xdt,f0,iaptype,xdt1,f1,snr2,dat4,idec)
!       idec=-1   !### TEMPORARY ###
          call timer('q65loops',1)
          if(idec.ge.0) then
             dtdec=xdt1
             f0dec=f1
             go to 200       !Successful decode, we're done
          endif
       enddo  ! ipass

200    decoded='                                     '
       if(idec.ge.0) then
! Unpack decoded message for display to user
          write(c77,1000) dat4(1:12),dat4(13)/2
          call unpack77(c77,0,decoded,unpk77_success) !Unpack to get msgsent
          nsnr=nint(snr2)
          call this%callback(nutc,snr1,nsnr,dtdec,f0dec,decoded,    &
               idec,nused,ntrperiod)
          if(iand(ndepth,128).ne.0) call q65_clravg    !AutoClrAvg after decode
          call sec0(1,tdecode)
          open(22,file=trim(data_dir)//'/q65_decodes.dat',status='unknown',     &
               position='append',iostat=ios)
          if(ios.eq.0) then
! Save decoding parameters to q65_decoded.dat, for later analysis.
             write(cmode,'(i3)') ntrperiod
             cmode(4:4)=char(ichar('A')+nsubmode)
             c6=hiscall(1:6)
             if(c6.eq.'      ') c6='<b>   '
             c4=hisgrid(1:4)
             if(c4.eq.'    ') c4='<b> '
             fmt='(i6.4,1x,a4,5i2,3i3,f6.2,f7.1,f7.2,f6.1,f6.2,'//   &
                  '1x,a6,1x,a6,1x,a4,1x,a)'
             if(ntrperiod.le.30) fmt(5:5)='6'
             write(22,fmt) nutc,cmode,nQSOprogress,idec,idf,idt,ibw,nused,    &
                  icand,ncand,xdt,f0,snr1,snr2,tdecode,mycall(1:6),c6,c4,     &
                  trim(decoded)
             close(22)
          endif
       endif
    enddo

900 return
  end subroutine decode

end module q65_decode