;+
;NAME:
;mmproc_setup - setup routine for mmproc
;SYNTAX: numPat=mmproc_setup(corfile,scndata,lun,retsl,indForPat,$
;                   brdToUse,nfits,
;                  mmInfo_arr,hb_arr,beamin_arr,beamout_arr,stkOffsets_chnl_arr,
;                   filesavenamemm0, filesavenamemm4,onlymm4=onlymm4,$
;                  tcalxx_board=tcalxx_board,tcalyy_board=tcalyy_board,$
;                   sl=sl,board=board,rcvnam=rcvnam,byChnl=byChnl,
;                   sourcename=sourcename,npatterns=npatterns,
;                   dirsave=dirsave,dirplot=dirplot)
;ARGS:
;   corfile: string filename with correlator data (includes path)
;   scndata: {scndata} observing pattern parameters.
;RETURNS:
;           numPat: int total number of patterns to do.
;          retsl[]:{sl} scan list of entire file
; indForPat[numPat]: int pointers into retsl[] for start of each pattern to do.
;          brdToUse: int   -1--> all boards, or board number 0..3
;             nfits: int    total number of fits to do. NumPat*numbrds
;  mmInfo_arr[nfits]:{mueller} hold results from fits
; beamin_arr[nfits]:{beaminput} input data before fits
;beamout_arr[nfits]:{mmoutput} output from fits
;   filesavenamemm0: string save filename for mm0 1d fits
;   filesavenamemm4: string save filename for mm4 mueller matrix computations
;
;KEYWORDS:
;tcalxx_board[]: float if positive then use these value for calxx 
;tcalyy_board[]: float if positive then use these values for calyy
;   sl[]:{sl}   scanlist user passes in (optional)
;  board: int   0..3 process only this board
; rcvnam: string process only this receiver
; sourcename[]:string process only these sources
; npatterns:int stop after processing this many patterns.
;   dirsave:string  directory for save files. default is current
;   dirplot:string  directory for plot files. default is current
;   onlymm4:    if set then only do mm4 processing. input the save file
;               and do the subsetting they want
;
;DESCRIPTION: 
;   Scan the file, figure out where the patterns are, make any subset
;of file they request, initializes variables.
;-
;01jan04 - return tcalxx_430 back to caller as keyword
function mmproc_setup,corfile,scndata,lun,retsl,indForPat, brdToUse,$
                   nfits,mmInfo_arr,hb_arr,beamin_arr,beamout_arr,$
                   stkOffsets_chnl_arr,filesavenamemm0,filesavenamemm4,$
                   tcalxx_board=tcalxx_board,tcalyy_board=tcalyy_board,$
                   sl=sl,board=board,rcvnam=rcvnam,onlymm4=onlymm4,$
                   sourcename=sourcename,npatterns=npatterns ,byChnl=byChnl,$
				   dirsave=dirsave, dirplot=dirplot,$
				   tcalxx_430ch=tcalxx_430ch,tcalyy_430ch=tcalyy_430ch
    norcvr=' '
    rcvnumAr  = [1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,51,61,$
                 100,  101,  121]
    rcvnamAr = ['327' ,'430' ,'800' ,norcvr,'lbw' ,'lbn' ,'sbw','sbh', $
             'cb' ,'cbh','xb','sbn' ,norcvr,norcvr,norcvr,'noise' , $
             'lbwifw' ,'lbnifw' ,'430ch' ,'chlb' ,'sb750' ]
    lun=-1
    if not keyword_set(onlymm4) then begin
;
;   check that the  file exists.
;
    if (file_exists(corfile) eq 0 ) then goto,nofile
;
;   open file, scan it.
;
    openr,lun,corfile,/get_lun
    if not keyword_set(sl) then begin
        print,'scanning file ',corfile
        sl=getsl(lun)
    endif
    retsl=sl
;
;   find all complete patterns in file
;
    nfound=corfindpat(retsl,indForPat,pattype=4)
    print,'Found ',nfound, 'patterns'
    if nfound lt 1 then goto,nopatterns
;
;   do any subsetting they requested
;
    brdToUse=-1
    if n_elements(board) gt 0 then begin    ; just 1 board
        ind=where(retsl[indForPat].numfrq ge board+1,count)
        if count eq 0 then goto, nopatterns
        indForPat=indForPat[ind]
        brdToUse=board[0]
    endif
    if keyword_set(sourcename) then begin
        iflag=intarr(n_elements(indForPat))
        for i=0,n_elements(sourcename)-1 do begin &$
            ind=where(retsl[indForPat].srcname eq sourcename[i],count) &$
            if count gt 0 then iflag[ind]=1 &$
        endfor
        ind=where(iflag eq 1,count)
        if count eq 0 then goto,nopatterns
        indForPat=indForPat[ind]
    endif
    if keyword_set(rcvnam) then begin
        ind=where(rcvnam eq rcvnamAr,count)
        if count eq 0 then goto,no_rcvnam
        rcvnum=rcvnumAr[ind[0]]
        ind=where(retsl[indForPat].rcvnum eq rcvnum,count)
        if count eq 0 then goto,no_rcvnam
        indForPat=indForPat[ind]
    endif
    numPat=n_elements(indForPat)
    if keyword_set(npatterns) then begin
        numPat= npatterns < numPat
        indForPat=indForPat[0:numPat-1]
    endif

    if numPat ne nfound then print,'Using ',numPat,' patterns'
;
;   now count the number of boards in all the scans
;   
    if brdToUse  ne -1 then begin   ; 1 board per pattern
        nfits=numPat
    endif else begin
        nfits=total(retsl[indForPat].numfrq)
    endelse
;
;   allocate the stuctures:
;
    mmInfo_arr=replicate({mueller},nfits)
    hb_arr=replicate({hdr},4,nfits)
    beamin_arr =replicate({beaminput},nfits)
    beamout_arr=replicate({mmoutput},nfits)
    if  keyword_set(byChnl) then begin
        stkOffsets_chnl_arr=fltarr(scndata.nchnls,4,scndata.ptsPerStrip,$
                                   scndata.nrstrips,nfits)
    endif
    endif   ; not onlymm4

;DEFINE THE ESTIMATE FOR DPHASE/DFREQ IN UNITS OF RADIANS PER MHZ...
;A NONFLIPPED RECEIVER WILL HAVE ROUGHLY THIS PHASE SLOPE...
    scndata.dpdf = -0.10

;------------------ CAL MATTERS ------------------------------
         
;IF YOU WISH TO DEFINE YOUR OWN CAL TEMPERATURES:
;TO USE CAL VALUES IN THE HEADER, MAKE THESE NEGATIVE
;MAKING THESE POSITIVE MEANS THESE ARE USED INSTEAD.
    scndata.tcalxx_board = -[ 10.77,10.81,10.64,10.33]
    scndata.tcalyy_board = -[ 9.18, 9.38, 9.32, 9.62]
    if n_elements(tcalxx_board) gt 0 then begin
        for i=0,n_elements(tcalxx_board) -1 do scndata.tcalxx_board[i] =tcalxx_board[i]
    endif
    if n_elements(tcalyy_board) gt 0 then begin
        for i=0,n_elements(tcalyy_board) -1 do scndata.tcalyy_board[i] =tcalyy_board[i]
    endif


;DEFINE CALS FOR 430CH...
    tcalxx_430ch = 27.4
    tcalyy_430ch = 39.6

    tcalxx_430ch = 47.5 ;/*pjp 25feb05*/
    tcalyy_430ch = 31. 

;-----------------FILENAMES-------------------------

   filename=corfile
   ind=strpos(corfile,'/',/reverse_search)
   if ind ne -1 then filename=strmid(corfile,ind)
   if not keyword_set(dirsave) then dirsave = './'
   if not keyword_set(dirplot) then dirplot = './'
   dirsave=strtrim(dirsave,2)
   dirplot=strtrim(dirplot,2)
   if dirsave eq '' then dirsave='./'
   if dirplot eq '' then dirplot='./'

    filesavenamemm0 = dirsave + 'mm0_' + $
         strmid( filename, strpos( filename, '.')+1) + '.sav'

    filesavenamemm4 = dirsave + 'mm4_' + $
         strmid( filename, strpos( filename, '.')+1) + '.sav'

    if keyword_set(onlymm4) then begin
        restore,filesavenamemm0
        numPat=n_elements(beamin_arr)
        if keyword_set(byChnl) then restore,filesavenamemm0 + '.byChnl'
    endif

return,numPat

nopatterns:
    print,'No calibration patterns meeting specs found.',string(7b)
    goto,errout
;
nofile:
    print,'Filename:',corfile,' not found',string(7b)
    goto,errout
no_rcvnam:
    print,'Bad receiver name: ',rcvnam,'.  Valid names are:',string(7b)
    print,rcvNamAr
    goto,errout
errout:
    if lun ne -1 then free_lun,lun
    lun=-1
    return,0
end
