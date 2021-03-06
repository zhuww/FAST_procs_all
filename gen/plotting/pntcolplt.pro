pro pntcolplt, xd, yd, zd, xra, yra, zra, psname=psname, $
   xsize=xsize, ysize=ysize, charsize=charsize, bg=bg, $
   axthk=axthk, xtit=xtit, ytit=ytit, ztit=ztit, tit=tit, psym=psym, $
   axcharsize=axcharsize, symsize=symsize

;+
; NAME: PNTCOLPLT
;
; PURPOSE: plot points in x, y with pseudocolor representing z.
;
; CALLING SEQUENCE:
; pntcolplt, xd, yd, zd, xra, yra, zra, psname=psname, $
;   xsize=xsize, ysize=ysize, charsize=charsize, bg=bg, $
;   axthk=axthk, xtit=xtit, ytit=ytit, ztit=ztit, tit=tit, psym=psym, $
;   axcharsize=axcharsize, symsize=symsize
;
; INPUTS:
;       XD - the x data values
;       YD - the y data values
;       ZD - the z data values (z is represented by color)
;       XRA - the xrange 2-element vector
;       YRA - the yrange 2-element vector
;       ZRA - the zrange 2-element vector
;
; KEYWORD PARAMETERS:
;       PSNAME - name of ps file. if undefined, it's X
;       XSIZE - default=6 in
;       YSIZE - default=6 in
;       CHARSIZE - default=2
;       BG - if set, fills plot background to gray
;       AXTHK - x and y axis thickness. default=6
;       XTITLE - x axis title
;       YTITLE - y axis title
;       ZTITLE - z colorbar title
;       TITLE - global title
;       PSYM - default=3
;       AXCHARSIZE - x, y axis character sizes
;       SYMSIZE - plot sym size.
;
; MODIFICATION HISTORY: /home/heiles/dzd4/heiles/arecibo/galfa_nvss; try
; play3.idl; pntcolplt.sav
;-

;TURN OFF DECOMPOSED COLOR TO ENABLE COLOR TABLES...
device, dec=0
loadct,0

if n_elements( xsize) eq 0 then xsize=6
if n_elements( ysize) eq 0 then ysize=6
if n_elements( charsize) eq 0 then charsize=2
if n_elements( axthk) eq 0 then axthk=6
if n_elements( psym) eq 0 then psym=3
if n_elements( axcharsize) eq 0 then axcharsize=2
if n_elements( symsize) eq 0 then symsize=2
if n_elements( bg) ne 0 then bgfill, !gray

if n_elements( psname) eq 0 then ps=0 else ps=1
if ps ne 0 then begin
        psopen, psname, /times, /bold, /isolatin1, /color, $
        xsize=xsize, ysize=ysize, /inches
endif

setcolors, /sys

;PLOT THE POINTS WITH /NODATA SET TO ESTABLISH AXES
plot, xd, yd, charsize=charsize, position=[.15,0.15,.76,.88], $
        /nodata, font=ps-1, $
;        symsize=symsize, psym=psym, $
        xtit=xtit, /xstyle, xthick=axthk, xcharsize=axcharsize, xra=xra, $
        ytit=ytit, /ystyle, ythick=axthk, ycharsize=axcharsize, yra=yra, $
        tit=tit, /noerase
sharpcorners, thick=axthk

xtemp=!x
ytemp=!y
ptemp=!p

pseudo_ch, colr

;PLOT THE POINTS IN COLOR...
if n_elements( symsize) eq 1 then begin
   plots, xd, yd, psym=psym, color=bytscl( zd, min=zra[0], max=zra[1]), $
       symsize=symsize
endif else begin
   pcolor=bytscl( zd, min=zra[0], max=zra[1])
         for np= 0l, n_elements( xd)-1l do $
            plots, xd[np], yd[np], psym=psym, $
            color= pcolor[ np], symsize=symsize[ np]
endelse

loadct,0

colorbar, position=[.79, .15, .85, .88], /vertical, $
        rgb=colr, crange= zra, $
        format='(f4.1)', $
;       irange=[0,0], divisions=1, $
        bottom=1, top=254, $
        color=255* (ps eq 0), font=ps-1, $
        charsize=axcharsize, xthick=3, ythick=3, ytit=ztit
sharpcorners, thick=axthk
loadct,0

if (ps ne 0) then begin
        psclose
        device, /dec
     endif else begin
        !x= xtemp
        !y= ytemp
        !p= ptemp
     endelse

setcolors, /sys

;device, /dec

return
end
