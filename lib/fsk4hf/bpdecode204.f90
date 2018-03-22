subroutine bpdecode204(llr,apmask,maxiterations,decoded,cw,nharderror,iter)
!
! A log-domain belief propagation decoder for the (204,68) code.
!
integer, parameter:: N=204, K=68, M=N-K
integer*1 codeword(N),cw(N),apmask(N)
integer  colorder(N)
integer*1 decoded(K)
integer Nm(6,M)  ! 4, 5, or 6 bits per check 
integer Mn(3,N)  ! 3 checks per bit
integer synd(M)
real tov(3,N)
real toc(6,M)
real tanhtoc(6,M)
real zn(N)
real llr(N)
real Tmn
integer nrw(M)

data colorder/                                                              &
         0,  1,  2,  3,  4,  5, 47,  6,  7,  8,  9, 10, 11, 12, 58, 55, 13, &
        14, 15, 46, 17, 18, 60, 19, 20, 21, 22, 23, 24, 25, 57, 26, 27, 49, &
        28, 52, 65, 16, 50, 73, 59, 68, 63, 29, 30, 31, 32, 51, 62, 56, 66, &
        45, 33, 34, 53, 67, 35, 36, 37, 61, 69, 54, 38, 71, 82, 39, 77, 80, &
        83, 78, 84, 48, 41, 85, 40, 64, 75, 96, 74, 72, 76, 86, 87, 89, 90, &
        79, 70, 92, 99, 93,101, 95,100, 97, 94, 42, 98,103,105,102, 43,104, &
        88, 44,106, 81,107,110,108,111,112,109,113,114,117,118,116,121,115, &
       119,122,120,125,129,124,127,126,128, 91,123,133,131,130,134,135,137, &
       136,132,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152, &
       153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169, &
       170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186, &
       187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203/

data Mn/       &
   1,  38, 107, &
   2,   7, 114, &
   3,  48, 106, &
   4,  79,  94, &
   5,  97, 108, &
   6,  50, 122, &
   8,  78, 134, &
   9,  55,  65, &
  10,  62, 100, &
  11,  16,  99, &
  12, 113, 119, &
  13,  31, 125, &
  14,  15, 127, &
  17,  87, 103, &
  18,  81,  98, &
  19,  43,  77, &
  20, 102, 130, &
  21,  36, 111, &
  22,  23,  60, &
  24,  39, 112, &
  25,  37,  42, &
  26,  41,  51, &
  27,  67,  70, &
  28,  64, 136, &
  29,  61,  68, &
  30,  91, 124, &
  32,  80, 121, &
  33,  40, 117, &
  34,  35,  90, &
  44,  88,  93, &
  45, 128, 133, &
  46,  56,  69, &
  47,  49,  52, &
  53,  76, 131, &
  54, 104, 116, &
  57,  84,  86, &
  58, 120, 135, &
  59,  75,  92, &
  63,  71, 109, &
  66,  74, 126, &
  72,  85, 105, &
  73,  82,  95, &
  83,  89, 123, &
  96, 115, 118, &
 101, 110, 129, &
  52,  99, 132, &
   1,   3,  20, &
   2,  77,  89, &
   4,  72,  75, &
   5,  34,  79, &
   6,  24, 130, &
   7,  48,  88, &
   8,  36, 116, &
   9,  71, 114, &
  10,  87, 101, &
  11,  22, 121, &
  12,  50,  64, &
  13,  39,  53, &
  14,  41,  78, &
  15,  68,  96, &
  16,  83,  90, &
  17,  23,  45, &
  18,  47, 126, &
  19,  70,  91, &
  21,  57,  76, &
  25, 110, 117, &
  26,  82, 135, &
  27,  46,  58, &
  28,  37,  56, &
  29,  66, 102, &
  30,  62, 125, &
  31,  85,  93, &
  32, 104, 113, &
  33,  81,  92, &
  35, 100, 118, &
  38,  95, 133, &
  40,  86, 109, &
  42,  61, 124, &
  43,  59, 119, &
  44,  49, 134, &
  51,  97, 122, &
  54, 105, 107, &
  55, 128, 136, &
  60,  67,  84, &
  63, 112, 115, &
  65,  74, 131, &
  69,  80,  94, &
  73,  98, 123, &
 103, 130, 134, &
  46, 106, 111, &
   1,  84, 108, &
 120, 129, 132, &
  65,  75, 127, &
   2,  80, 101, &
   3, 118, 119, &
   4,  52, 124, &
   5,  13,  68, &
   6,  27,  81, &
   7,  51,  76, &
   8,  77, 108, &
   9,  31,  58, &
  10,  18,  57, &
  11,  63, 105, &
  12,  14, 132, &
  15,  56, 123, &
  16,  21, 128, &
  17,  37,  59, &
  19,  85, 126, &
  20,  71,  91, &
  22,  26, 117, &
  23,  79,  98, &
  24,  32,  95, &
  25,  90,  93, &
  28,  49, 109, &
  29, 116, 120, &
  30,  54, 136, &
  33,  53, 107, &
  34,  64, 103, &
  35,  39,  67, &
  36,  71,  73, &
  38,  47, 125, &
  40,  66,  94, &
  41,  70, 104, &
  42,  55, 112, &
  43,  44,  82, &
  29,  45,  88, &
  48,  86, 127, &
  50,  72, 135, &
  60,  74,  96, &
  61, 121, 131, &
  62,  78,  92, &
  69, 100, 133, &
  83, 122, 129, &
  87,  97, 106, &
  89, 102, 113, &
  24,  99, 108, &
  20,  72, 110, &
 111, 115, 117, &
  35,  52, 114, &
   1,  44,  94, &
   2,  23, 107, &
   3,  81, 136, &
   4,   8,  96, &
   5,  37,  70, &
   6,  43, 131, &
   7, 103, 115, &
   9,  94, 122, &
  10,  68,  82, &
  11,  56,  88, &
  12,  46, 126, &
  13,  16,  75, &
  14,  79, 112, &
  15,  47, 110, &
  17,  36,  39, &
  18,  63, 120, &
  19,  22,  55, &
  21,  49, 113, &
  25,  54,  57, &
  26,  89, 125, &
  27, 101, 109, &
  28,  31,  60, &
  30,  74,  97, &
  32,  92,  93, &
  33,  83,  91, &
  34,  58, 121, &
  38,  65, 111, &
  40,  99, 118, &
   3,  41,  61, &
  42,  50, 100, &
  45,  78, 106, &
  48,  95, 129, &
  51,  85, 133, &
  53,  59,  69, &
  11,  62,  66, &
  64,  73, 124, &
  67, 123, 134, &
  76, 104, 132, &
  77, 100, 127, &
  36,  80, 119, &
  84, 102, 135, &
  86, 105, 124, &
   4,  87, 128, &
  90, 106, 116, &
  65,  98, 130, &
  92, 108, 114, &
   1,  52, 121, &
   2,  84, 117, &
   5,  83, 105, &
   6,  15,  63, &
   7,  28,  82, &
   8,  32, 135, &
   9, 104, 134, &
   9,  10,  89, &
  12,  62, 107, &
  13,  40, 103, &
  14,  31,  95, &
  16,  27,  74, &
  17,  90, 132, &
  18,  34,  69, &
  19, 103, 129, &
  20,  76,  87, &
  21,  22, 130, &
  23,  25,  99, &
  24, 101, 126/

data Nm/               &
   1,  47,  91, 140, 186,   0, &
   2,  48,  94, 141, 187,   0, &
   3,  47,  95, 142, 168,   0, &
   4,  49,  96, 143, 182,   0, &
   5,  50,  97, 144, 188,   0, &
   6,  51,  98, 145, 189,   0, &
   2,  52,  99, 146, 190,   0, &
   7,  53, 100, 143, 191,   0, &
   8,  54, 101, 147, 192, 193, &
   9,  55, 102, 148, 193,   0, &
  10,  56, 103, 149, 174,   0, &
  11,  57, 104, 150, 194,   0, &
  12,  58,  97, 151, 195,   0, &
  13,  59, 104, 152, 196,   0, &
  13,  60, 105, 153, 189,   0, &
  10,  61, 106, 151, 197,   0, &
  14,  62, 107, 154, 198,   0, &
  15,  63, 102, 155, 199,   0, &
  16,  64, 108, 156, 200,   0, &
  17,  47, 109, 137, 201,   0, &
  18,  65, 106, 157, 202,   0, &
  19,  56, 110, 156, 202,   0, &
  19,  62, 111, 141, 203,   0, &
  20,  51, 112, 136, 204,   0, &
  21,  66, 113, 158, 203,   0, &
  22,  67, 110, 159,   0,   0, &
  23,  68,  98, 160, 197,   0, &
  24,  69, 114, 161, 190,   0, &
  25,  70, 115, 126,   0,   0, &
  26,  71, 116, 162,   0,   0, &
  12,  72, 101, 161, 196,   0, &
  27,  73, 112, 163, 191,   0, &
  28,  74, 117, 164,   0,   0, &
  29,  50, 118, 165, 199,   0, &
  29,  75, 119, 139,   0,   0, &
  18,  53, 120, 154, 179,   0, &
  21,  69, 107, 144,   0,   0, &
   1,  76, 121, 166,   0,   0, &
  20,  58, 119, 154,   0,   0, &
  28,  77, 122, 167, 195,   0, &
  22,  59, 123, 168,   0,   0, &
  21,  78, 124, 169,   0,   0, &
  16,  79, 125, 145,   0,   0, &
  30,  80, 125, 140,   0,   0, &
  31,  62, 126, 170,   0,   0, &
  32,  68,  90, 150,   0,   0, &
  33,  63, 121, 153,   0,   0, &
   3,  52, 127, 171,   0,   0, &
  33,  80, 114, 157,   0,   0, &
   6,  57, 128, 169,   0,   0, &
  22,  81,  99, 172,   0,   0, &
  33,  46,  96, 139, 186,   0, &
  34,  58, 117, 173,   0,   0, &
  35,  82, 116, 158,   0,   0, &
   8,  83, 124, 156,   0,   0, &
  32,  69, 105, 149,   0,   0, &
  36,  65, 102, 158,   0,   0, &
  37,  68, 101, 165,   0,   0, &
  38,  79, 107, 173,   0,   0, &
  19,  84, 129, 161,   0,   0, &
  25,  78, 130, 168,   0,   0, &
   9,  71, 131, 174, 194,   0, &
  39,  85, 103, 155, 189,   0, &
  24,  57, 118, 175,   0,   0, &
   8,  86,  93, 166, 184,   0, &
  40,  70, 122, 174,   0,   0, &
  23,  84, 119, 176,   0,   0, &
  25,  60,  97, 148,   0,   0, &
  32,  87, 132, 173, 199,   0, &
  23,  64, 123, 144,   0,   0, &
  39,  54, 109, 120,   0,   0, &
  41,  49, 128, 137,   0,   0, &
  42,  88, 120, 175,   0,   0, &
  40,  86, 129, 162, 197,   0, &
  38,  49,  93, 151,   0,   0, &
  34,  65,  99, 177, 201,   0, &
  16,  48, 100, 178,   0,   0, &
   7,  59, 131, 170,   0,   0, &
   4,  50, 111, 152,   0,   0, &
  27,  87,  94, 179,   0,   0, &
  15,  74,  98, 142,   0,   0, &
  42,  67, 125, 148, 190,   0, &
  43,  61, 133, 164, 188,   0, &
  36,  84,  91, 180, 187,   0, &
  41,  72, 108, 172,   0,   0, &
  36,  77, 127, 181,   0,   0, &
  14,  55, 134, 182, 201,   0, &
  30,  52, 126, 149,   0,   0, &
  43,  48, 135, 159, 193,   0, &
  29,  61, 113, 183, 198,   0, &
  26,  64, 109, 164,   0,   0, &
  38,  74, 131, 163, 185,   0, &
  30,  72, 113, 163,   0,   0, &
   4,  87, 122, 140, 147,   0, &
  42,  76, 112, 171, 196,   0, &
  44,  60, 129, 143,   0,   0, &
   5,  81, 134, 162,   0,   0, &
  15,  88, 111, 184,   0,   0, &
  10,  46, 136, 167, 203,   0, &
   9,  75, 132, 169, 178,   0, &
  45,  55,  94, 160, 204,   0, &
  17,  70, 135, 180,   0,   0, &
  14,  89, 118, 146, 195, 200, &
  35,  73, 123, 177, 192,   0, &
  41,  82, 103, 181, 188,   0, &
   3,  90, 134, 170, 183,   0, &
   1,  82, 117, 141, 194,   0, &
   5,  91, 100, 136, 185,   0, &
  39,  77, 114, 160,   0,   0, &
  45,  66, 137, 153,   0,   0, &
  18,  90, 138, 166,   0,   0, &
  20,  85, 124, 152,   0,   0, &
  11,  73, 135, 157,   0,   0, &
   2,  54, 139, 185,   0,   0, &
  44,  85, 138, 146,   0,   0, &
  35,  53, 115, 183,   0,   0, &
  28,  66, 110, 138, 187,   0, &
  44,  75,  95, 167,   0,   0, &
  11,  79,  95, 179,   0,   0, &
  37,  92, 115, 155,   0,   0, &
  27,  56, 130, 165, 186,   0, &
   6,  81, 133, 147,   0,   0, &
  43,  88, 105, 176,   0,   0, &
  26,  78,  96, 175, 181,   0, &
  12,  71, 121, 159,   0,   0, &
  40,  63, 108, 150, 204,   0, &
  13,  93, 127, 178,   0,   0, &
  31,  83, 106, 182,   0,   0, &
  45,  92, 133, 171, 200,   0, &
  17,  51,  89, 184, 202,   0, &
  34,  86, 130, 145,   0,   0, &
  46,  92, 104, 177, 198,   0, &
  31,  76, 132, 172,   0,   0, &
   7,  80,  89, 176, 192,   0, &
  37,  67, 128, 180, 191,   0, &
  24,  83, 116, 142,   0,   0/

data nrw/    &
  5,5,5,5,5,5,5,5,6,5,5,5,5,5,5,5,5, &
  5,5,5,5,5,5,5,5,4,5,5,4,4,5,5,4,5, &
  4,5,4,4,4,5,4,4,4,4,4,4,4,4,4,4,4, &
  5,4,4,4,4,4,4,4,4,4,5,5,4,5,4,4,4, &
  5,4,4,4,4,5,4,5,4,4,4,4,4,5,5,5,4, &
  4,5,4,5,5,4,5,4,5,5,4,4,4,5,5,5,4, &
  6,5,5,5,5,5,4,4,4,4,4,4,4,4,5,4,4, &
  4,5,4,4,5,4,5,4,4,5,5,4,5,4,5,5,4/

ncw=3

decoded=0
toc=0
tov=0
tanhtoc=0
! initialize messages to checks
do j=1,M
  do i=1,nrw(j)
    toc(i,j)=llr((Nm(i,j)))
  enddo
enddo

ncnt=0

do iter=0,maxiterations

! Update bit log likelihood ratios (tov=0 in iteration 0).
  do i=1,N
    if( apmask(i) .ne. 1 ) then
      zn(i)=llr(i)+sum(tov(1:ncw,i))
    else
      zn(i)=llr(i)
    endif
  enddo

! Check to see if we have a codeword (check before we do any iteration).
  cw=0
  where( zn .gt. 0. ) cw=1
  ncheck=0
  do i=1,M
    synd(i)=sum(cw(Nm(1:nrw(i),i)))
    if( mod(synd(i),2) .ne. 0 ) ncheck=ncheck+1
!   if( mod(synd(i),2) .ne. 0 ) write(*,*) 'check ',i,' unsatisfied'
  enddo
! write(*,*) 'number of unsatisfied parity checks ',ncheck
  if( ncheck .eq. 0 ) then ! we have a codeword - reorder the columns and return it
    codeword=cw(colorder+1)
    decoded=codeword(M+1:N)
    nerr=0
    do i=1,N
      if( (2*cw(i)-1)*llr(i) .lt. 0.0 ) nerr=nerr+1
    enddo
    nharderror=nerr
    return
  endif

  if( iter.gt.0 ) then  ! this code block implements an early stopping criterion
!  if( iter.gt.10000 ) then  ! this code block implements an early stopping criterion
    nd=ncheck-nclast
    if( nd .lt. 0 ) then ! # of unsatisfied parity checks decreased
      ncnt=0  ! reset counter
    else
      ncnt=ncnt+1
    endif
!    write(*,*) iter,ncheck,nd,ncnt
    if( ncnt .ge. 5 .and. iter .ge. 10 .and. ncheck .gt. 15) then
      nharderror=-1
      return
    endif
  endif
  nclast=ncheck

! Send messages from bits to check nodes 
  do j=1,M
    do i=1,nrw(j)
      ibj=Nm(i,j)
      toc(i,j)=zn(ibj)  
      do kk=1,ncw ! subtract off what the bit had received from the check
        if( Mn(kk,ibj) .eq. j ) then  
          toc(i,j)=toc(i,j)-tov(kk,ibj)
        endif
      enddo
    enddo
  enddo

! send messages from check nodes to variable nodes
  do i=1,M
    tanhtoc(1:6,i)=tanh(-toc(1:6,i)/2)
  enddo

  do j=1,N
    do i=1,ncw
      ichk=Mn(i,j)  ! Mn(:,j) are the checks that include bit j
      Tmn=product(tanhtoc(1:nrw(ichk),ichk),mask=Nm(1:nrw(ichk),ichk).ne.j)
      call platanh(-Tmn,y)
!      y=atanh(-Tmn)
      tov(i,j)=2*y
    enddo
  enddo

enddo
nharderror=-1
return
end subroutine bpdecode204
