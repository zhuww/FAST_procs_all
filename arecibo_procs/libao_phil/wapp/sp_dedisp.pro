;+
;NAME:
;sp_dedisp - dedisperse a wapp data file.
;SYNTAX: npnts=sp_dedisp,file,dm,dedisp,refRf=refRf,hdr=hdr,$
;               maxSmp=maxSmp)
;ARGS:
;   file: string    name of file to de disperse
;    dm : double  dispersion measure to use
;
;KEYWORDS:
;   refRf:double   reference frequency to use for dedispersion. The default
;                  is the first bin of each band.
;   maxSmp:long    Maxium number of samples to return
;  flip   :        if set then flip the frequency direction from
;                  whatever the header says it is (use this if there
;                  is a bug in the header values for iflo_flip).
; _extra:          parameters passed to wappget(). /lvlcor,/han) 
;
;RETURNS:
;   npnts:long     the number of samples in the dedispersed time series
;   dedispA[npnts,nspc]float dedispersed series. Npnts total power by
;                  the number of spectra per sample for this wapp board
;                  it can be 1, 2, or 4
;   hdr  :{wapphdr} the header from the first wapp file.
;
;DESCRIPTION:
;   Dedisperse a wapp pulsar data file. The user passes in the
;file name and the dispersion measure. The dedispersed time series
;is passed back in dedispA (polA) and dedispB (polB). If the file 
;contains  polarization data then the cross spectra are ignored (some day
;i'll get to that..). The header can be returned in the keyword  hdr=hdr.
;
;   By default the reference frequency is the high frequency edge of the
;band. The user can change this with the refRf keyword. 
;
;NOTES:
;  1. The code was borrowed from duncan lorimers sigproc() (so sp_). Hopefully
;     I haven't added too many bugs.
;  2. The first dedispersed point will include power that belongs in any
;     time samples before the first sample. At the first sample, all
;     frequencies below the reference frequency belong in the first sample
;     or previous samples (depending on the dm and freq).
;  3. This returns the dedispersed time series for the entire file
;     (or maxsmp). Make sure that the buffers is not too big.
;  4. This needs to be updated to processes multiple files and 
;     write the data directly to disc (but then you should probably just use
;     dunc's sigproc routines)...
;SEE ALSO:
;   sp_dedisp1,sp_dmdelay,sp_dmshift,wappget.
;-
;
;
; timing 2 megsample 32chan 4pol fusion01
; 1mb input buffer    [145.9,151.87498,141.23375,141.06038] : 145
; 16 mb input buffer   [ 153  ,148,     ,151      ,149]      : 150
; 256kb input buffer   118.5 secs
; 64kb input buffer    116.5 
; 16kb input buffer    125
; 128k                 115,116,124,120
; 512kb                132 132
; 64kb input buffer    116.
;
; NOTES:
;27MAY06 : switched arg call to work with alfa. multiple brds per wapp
;          number of boards in this wapp
;03jun06 : fixed up dedisp_1.. i think it wasn't working. removed 
;          flip=flip.. just use f1,df to specify the first channel
;          and the step
;
function  sp_dedisp,flist,dm,dedisp,flip=flip,refRf=refRf,$
            maxSmp=maxSmp, _extra=e
;
;   
;  till we put disc i/o in limit number of returned samples to
;  1e8 . about 800mb for 2 pols
;
    if not keyword_set(maxsmp) then maxsmp=1e8  
    maxFileSize=2.2d9
    inpBufSize =1024L*1024*16L          ; make it around 16 mb
    inpBufSize =1024L*64L           ; make it around 16 mb
    inpBufSize =1024L*512L          ; make it around 16 mb
    inpBufSize =1024L*64L           ; make it around 16 mb
    inpBufSize =1024L*128L          ; make it around 16 mb
    nfiles=n_elements(flist)
    smpOff=0L                       ; which sample buffer starts on
    if n_elements(flip) eq 0 then flip=0
    for i=0,nfiles-1 do begin
        lun=-1
        openr,lun,flist[i],/get_lun,error=err
        if err ne 0 then begin
            print,'file:',flist[i],' open err:',!error_state.msg
            goto,errout
        endif
        istat=wappgethdr(lun,hdr)
        if istat eq 0 then begin
            print,'file:',flist[i],' get hdr error'
            goto,errout
        endif
        if i eq 0 then begin
;
;   figure out the size of things 
;
;           need to check sum pol 
;
            bytePerNum=((hdr.lagformat and 7) eq 0) ? 2L : 4L
            nchan=hdr.num_lags
            nifs =hdr.nifs
            nbrds=(hdr.isalfa)?2:1
            smpTm=hdr.samp_time*1d-6
            npol=(nifs eq 4)? 2: nifs
            bw  = hdr.bandwidth
            cfr = hdr.cent_freq
            bytes1Rec=nifs*nbrds*nchan*bytePerNum
            flipsgn= (hdr.freqinversion)?-1 : 1 
            flipsgn= (hdr.iflo_flip)? -flipsgn:flipsgn
            if keyword_set(flip) then flipsgn*=-1
            nspcSmp=npol*nbrds
;
;           smp 1 file: assume 2gb max
;
            maxsmp1file=maxFileSize/(nifs*nbrds*nchan*bytePerNum)
            inpRecReq=inpBufSize/bytes1Rec
;
;           get the defaults for dedisp
;
            f1=cfr - flipSgn*(bw/2D)
            df=flipSgn*bw/(nchan*1d)
            if not keyword_set(refRf) then refRf=cfr + bw/2D
            smpOff=0L
            shiftAr=sp_dmshift(f1,df,nchan,dm,smpTm,refRf=refRf)
            slop=min(shiftar)
            dedisp=(nspcSmp eq 1)?fltarr(maxsmp1file+slop)$
                                 :fltarr(maxsmp1file+slop,nspcSmp) 
        endif
        done=0
        while ((nrecs=wappget(lun,hdr,d,nrec=inpRecReq,_extra=e)) gt 0) $
                do begin
            if (nrecs + smpOff) ge maxSmp then begin
                nrecs=maxSmp - smpOff
                print,'hit maxsmp limit of:',maxSmp,' tm samples'
                done=1
                d=(nspcSmp gt 1)?d[*,*,0:nrecs-1]: d[*,0:nrecs-1]
            endif
                
            sp_dedisp1,d,f1,df,dm,smpTm,smpOff,deDisp,refRf=refRf
            smpOff+=nrecs
            if smpOff ge maxSmp then break
        endwhile
        free_lun,lun
        dedisp=(nspcSmp eq 1)?deDisp[0L:smpOff-1] $
                             :deDisp[0L:smpOff-1,*]
        if done then break
    endfor
    return,smpOff
errout:
    if lun gt 0 then free_lun,lun
    return,-1
end
