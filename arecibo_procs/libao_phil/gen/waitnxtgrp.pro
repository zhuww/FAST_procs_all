;+
;NAME:
;waitnxtgrp - wait for next group from the file to become available
;SYNTAX:
;     istat=waitnxtgrp(lun,[maxwaitSecs],bytesingrp=bytesingrp)
;ARGS:
;     lun: assigned to file
;OPTIONAL ARGS:
;     maxwait: maximum number of seconds to wait before returning. Default
;             is 99999
;RETURNS:
;     istat: return status. 0 ok, -1 timedout, -2 not lined up with a header.
;bytesingrp: long bytes in the next group. You can use this to position
;                 to the end of the new group
;DESCRIPTION:
;   Wait for the next group from the file to be available. Return 0
; if ok, -1 if timeout. You can then read the data in with corget. On
; return, the lun is left positioned at the start of the group to read.
;EXAMPLE:
;   Assume you are monitoring the online datafile.
;   if waitnxtgrp(lun) ne 0 then .. error message
;   istat=corget(lun,b)             ;input the data
;SEE ALSO:
;    corget
;-
function waitnxtgrp,lun,maxwait,secperwait=secperwait,bytesingrp=bytesingrp
    on_error,2
    on_ioerror,waitloop
    needwait=0
    hdr={hdrstd}
    gothdr=0L
    waitcnt=0L
    secperwaitL=1.               ; each wait 1 sec 
    if n_elements(secperwait) gt 0 then secperwaitl=secperwait
    retstat=-999L
    byte=0b
    bytesingrp=0L
;
    if (n_elements(maxwait) eq 0) then maxwait=99999
    point_lun,-lun,startpos         ; get current position 
    curpos=startpos
    while retstat eq -999 do begin
;
;       read the header
;
        needwait=1
        if ( not gothdr) then begin
            readu,lun,hdr
            if chkswaprec(hdr) then begin
                hdr.reclen    =swap_endian(hdr.reclen)
                hdr.grpTotRecs=swap_endian(hdr.grpTotRecs)
                hdr.grpCurRec =swap_endian(hdr.grpCurRec)
            endif
            
            if ( string(hdr.hdrMarker) ne 'hdr_' ) then begin
                retstat=-2 
                goto,done
            endif
            gothdr=1
            curpos=curpos + hdr.reclen - 1  ; last byte of record
            point_lun,lun,curpos
        endif
;
;       position to last byte of rec and try to read it..
;
        readu,lun,byte
;
;       more records this group?
;
        if (hdr.grpCurRec lt hdr.grpTotRecs) then begin
            curpos=curpos+1
            gothdr=0                ; read a new header
            needwait=0
        endif else  begin
            retstat=0               ; done
            goto,done
        endelse
waitloop:
        if (needwait ) then begin
            waitcnt=waitcnt+1
            if (waitcnt ge maxwait) then begin
                retstat=-1 
            endif else begin
                wait,secperwaitl
                point_lun,lun,curpos
            endelse
        endif

    endwhile
done:
    if retstat eq 0 then begin
        point_lun,-lun,curpos
        bytesingrp= curpos-startpos
    endif
    point_lun,lun,startpos
    return,retstat
end
