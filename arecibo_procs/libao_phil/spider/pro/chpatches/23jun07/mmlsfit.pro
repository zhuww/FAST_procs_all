pro mmlsfit, pacoeffs, $
	muellerparams0, muellerparams1, $
;	qsrc0, usrc0, qsrc, usrc, sigqsrc, sigusrc, $
;	sigma, coeffs, sigcoeffs, problem, nloop, cov, $
	nloop, cov, $
	fixsrc=fixsrc, fixchi=fixchi, fixpsi=fixpsi, $
        parameter_fixup= parameter_fixup


;+
;PURPOSE: ls fit the basic parameters in the Mueller matrix, using the
;position angle coefficients array as input data. This does NOT discard
;points exceeding 3 sigma (there aren't enough points to discard any!)
;
;if PARAMETER_FIXUP IS SET, this version assumes a nominaally linear
;feed, so is suitable only for arecibo! our GBT version should be used
;for circular feeds or, alternatively:
;
;-------->> DON'T SET parameter_fixup FOR CIRCULAR FEEDS! <<------------
;
;----------------------------------------------------------------------
;
;CALLING SEQUENCE: SOME INPUTS AND OUTPUTS NOW PROVIDED WITH
;STRUCTURES...  
;mmlsfit, pacoeffs, $
;	muellerparams0, muellerparams1, $
;	nloop, cov, $
;	fixsrc=fixsrc, fixchi=fixchi, fixpsi=fixpsi, $
;        parameter_fixup= parameter_fixup
;
;INPUTS:
;	PACOEFFS, the output from stripfit_to_pacoeffs
;MUELLERPARAMS0 CONTAINS:
;	DELTAG0, the initial guess for the deltag in the Mueller matrix
;	....
;	PSI0, the initial guess for the deltag in the Mueller matrix

;	QSRC0, the initial guess for the source Stokes Q
;	USRC0, the initial guess for the source Stokes U
;	*** THE UNIT FOR ALL PHASE ANGLES IS ****RADIANS******

;KEYWORDS:
;	FIXSRC: Accepts QSRC0, USRC0 as correct and doesn't fit for them.
;Returns QSRC,USRC equal to QSRC0, USRC0.
;
;	FIXPSI: Accepts PSI0 as correct and doesn't fit for it. Returns
;PSI equal to PSI0. set RIXPSI for pure circular, as in LBN at 1415 MHz,
;to remove the degeneracy discussed in AOTM.
;
;PARAMETER_FIXUP: If set, it 'fixes up' parameters as follows:
;
;1. In case of neg EPSILON, makes it positive and adds !pi to 
;	its phase angle PHI.
;2. Converts PHI to the interval -!pi to !pi
;3. Converts PSI to the interval -!pi to !pi
;4. Converts ALPHA to the interval -!pi/2 to !pi/2.
;5. if alpha gt 45 deg, it adds 90 deg to alpha and 180 to psi and then
;does steps 3 and 4 again. This  fixes the degeneracy in 
;deriving alpha and pse in the lineaer case; see PASP paper, section
;5.1.


;----> THESE CONVERSIONS ARE ***NOT**** DONE TO THE COEFFS ARRAY (coeffs
;is used only internally, so don't sweat it! <-----

;OUTPUTS
;MUELLERPARAMS1 CONTAINS:
;	DELTAG, the fitted value for the deltag in the Mueller matrix
;	....
;	PSI, the fitted value for the deltag in the Mueller matrix
;		*** THE UNIT FOR ALL PHASE ANGLES IS ****RADIANS******

;	QSRC, the fitted value for the source Stokes Q
;	USRC, the fitted value for the source Stokes U
;	SIGMA, the sigma of the fitted points

;	COEFFS, the fitted values in array form
;	SIGCOEFFS, the errors of the fitted values in array form
;	PROBLEM, tells about problems in the nonlinear ls fit. Nonzero values
;indicate a fitting problem; see the program for details.
;	NLOOP, the number of loops in the nonlinear ls fit.
;	COV, the normalized covariance matrix

;HISTORY: 
;	written 9 oct 00 by carl
;	24 oct 02 frc changed from .01 to .0001, should reflect more accurate
;numerical derivative in double precision.
;	11jul04: study of convergence resulted in testing for fractional
;change of ax1 for quantities and change of ax1 radians for angles.
;       22 jun 07. corrected the parameter_fixup (it erroneously changed
;       alpha and psi only if epsilon were lt 0, which resulted in lots
;       of 90-deg-rotated mueller maatrices!!
;22 jun 07: fixed the erroneous parameter_fixup (see above under parameter_fixup)
;-

;common plotcolors

;DEFINE OUTPUT STRUCTURE...
muellerparams1= {muellerparams_carl}

;EXTRACT QUANS FROM INPUT STRUCTURE MUELLERPARAMS0
deltag0= muellerparams0.deltag 
epsilon0= muellerparams0.epsilon 
alpha0= muellerparams0.alpha
phi0= muellerparams0.phi
chi0= muellerparams0.chi 
psi0= muellerparams0.psi 

qsrc0= muellerparams0.qsrc
usrc0= muellerparams0.usrc

;DETERMINE THE SIZE OF THE ORIGINAL DATA ARRAYS...
alldatasize = 9

;DEFINE THE INTERNAL VARIABLES...
tdata= fltarr( 9)
tdata[ 0:2]= pacoeffs[ 0,0,1:3]
tdata[ 3:5]= pacoeffs[ 1,0,1:3]
tdata[ 6:8]= pacoeffs[ 2,0,1:3]

;AX1 IS THE PERCENTAGE OF CHANGE THAT WE ALLOW; 1% IS THE DEFAULT...
;IT IS FRACTIONAL FOR QUANTITIES AND NONFRACTIONAL, .01 RADIANS, FOR ANGLES
ax1 = 0.01
;ax1 = 0.0001
chkindx= intarr( 2)
chkindx= [0,1]
IF (KEYWORD_SET( FIXSRC) NE 1) THEN BEGIN
chkindx= intarr( 4)
chkindx[ 0:1]= [0,1]
endif

;A NONZERO PROBLEM INDICATES A PROBLEM...
problem=0

;DEFINE THE OUTPUT PARAMETERS.
;THESE ARE THE SAME AS THE PARAMETERS THAT ARE ITERATED.
nparams = 8
if (keyword_set( fixsrc)) then nparams=nparams-2
if (keyword_set( fixchi)) then nparams=nparams-1
if (keyword_set( fixpsi)) then nparams=nparams-1

deltag= double(deltag0)
epsilon= double(epsilon0)
alpha= double(alpha0)
phi= double(phi0)
chi= double(chi0)
psi= double(psi0)
qsrc= double(qsrc0)
usrc= double(usrc0)


;DEFINE FRACTION TO CHANGE FOR EVALUATING DERIVATIVES...
frc = 0.01d0
frc = 0.001d0

;DEFINE NLOOP_BAD, THE NR OF ITERATIONS FOR BAD POINTS...
nloop_bad = 0

;---------- BEGINNING OF ITERATION LOOP FOR BAD POINTS---------
ITERATE_BAD:

;DEFINE NLOOP, THE NR OF ITERATIONS IN THE NONLINEAR FIT...
nloop = 0

;HALFASSED IS THE MULTIPLIER FOR THE CORRECTIONS IN NONLINEAR REGIME.
halfassed = 0.5
;halfassed = 0.125

;DETERMINE THE SIZE OF THE DATA ARRAY...
datasize = 9

;DEFINE THE EQUATION-OF-CONDITION ARRAY, S...
s = dblarr(nparams, datasize)
vals= fltarr( nparams)

;------------- BEGIN THE NONLINEAR ITERATION LOOP----------------
ITERATE_NONLINEAR:
nloop= nloop+1

;EVALUATE THE DERIVATIVES...
nr= -1
;DM_DDELTAG
del = frc
deltag = deltag + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
deltag = deltag - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
deltag = deltag + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
vals[nr]= deltag

;DM_DEPSILON
del = frc
epsilon = epsilon + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
epsilon = epsilon - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
epsilon = epsilon + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
vals[nr]= epsilon

;DM_Dalpha
del = frc
alpha = alpha + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
alpha = alpha - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
alpha = alpha + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
vals[nr]= alpha

;DM_Dphi
del = frc
phi = phi + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
phi = phi - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
phi = phi + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
vals[nr]= phi

;DM_Dchi
IF (keyword_set( fixchi) ne 1) THEN BEGIN
del = frc
chi = chi + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
chi = chi - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
chi = chi + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
ENDIF
vals[ nr]= chi

;DM_Dpsi
IF (keyword_set( fixpsi) ne 1) THEN BEGIN
del = frc
psi = psi + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
psi = psi - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
psi = psi + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
ENDIF
vals[ nr]= psi

IF (keyword_set( fixsrc) ne 1) THEN BEGIN
;DM_Dqsrc
del = frc
qsrc = qsrc + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
qsrc = qsrc - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
qsrc = qsrc + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
chkindx[ 2]= nr
vals[ nr]= qsrc

;DM_Dusrc
del = frc
usrc = usrc + del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessplus
usrc = usrc - 2.d0*del
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guessminus
usrc = usrc + del
nr=nr+1 & s[ nr,*] = (guessplus- guessminus)/ (2.d0*del)
vals[ nr]= usrc
chkindx[ 3]= nr
ENDIF

;EVALUATE THE GUESSED MATRIX...
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, guess_tot,m_tot

;CREATE AND SOLVE THE NORMAL EQUATION MATRICES...
t = tdata- guess_tot
ss = transpose(s) ## s
st = transpose(s) ## t
ssi = invert(ss)
a = ssi ## st

;CHECK THE DERIVED PARAMETERS...

delt= a

;PRINT STUFF FOR STUDY OF CONVERGENCE PROPS...
;print, transpose(delt), format='(11f12.4)'
;print, vals, format='(11f12.4)'
;print, transpose( delt)/vals, format='(11f12.4)'
;fracts= abs( delt[ chkindx]/ vals[ chkindx])
;indx= where( fracts gt ax1, count)
;print, fracts
;print, ' '

;CHECK FOR SMALLNESS OF THE CORRECTIONS...
redoit= 0
indx= where(abs( delt) gt ax1, count)

;IF ALL CORRECTIONS ARE SMALL, THEN CHECK THE FRACTIONAL CHANGE IN 
;DELTAG, EPSILON, QSRC, USRC...
IF (COUNT EQ 0) THEN BEGIN
fracts= abs( delt[ chkindx]/ vals[ chkindx])
indx= where( fracts gt ax1, count)
ENDIF

;stop, 'CHECK FOR SMALLNESS OF THE CORRECTIONS...'

IF (count ne 0) then BEGIN
redoit=1
jndx = where( abs( delt) gt 1.2, count)
if (count ne 0) then delt[ jndx] = 1.2* sign( delt[jndx])
ENDIF

;print, a
;print, '***'
;print, delt
;stop

if (redoit eq 0) then halfassed= 1.0

;print, 'DELTAG ', deltag, delt[0]
;print, 'EPSILON ', epsilon,delt[1]
;print, 'ALPHA ', alpha, delt[2]
;print, 'PHI ', phi, delt[3]
;print, 'PSI ', psi, delt[4]
;print, 'QSRC ', qsrc, delt[5]
;print, 'USRC ', usrc, delt[6]

;stop
nr=-1
nr=nr+1 & deltag= deltag+ halfassed*delt[nr ]
nr=nr+1 & epsilon= epsilon+  halfassed*delt[nr ]
nr=nr+1 & alpha= alpha+  halfassed*delt[nr ]
nr=nr+1 & phi= phi+  halfassed*delt[nr ]

IF (keyword_set( fixchi) ne 1) THEN BEGIN
nr=nr+1 & chi= chi+  halfassed*delt[nr ]
ENDIF

IF (keyword_set( fixpsi) ne 1) THEN BEGIN
nr=nr+1 & psi= psi+  halfassed*delt[nr ]
ENDIF

IF (keyword_set( fixsrc) ne 1) THEN BEGIN
nr=nr+1 & qsrc= qsrc+  halfassed*delt[nr ]
nr=nr+1 & usrc= usrc+  halfassed*delt[nr ]
ENDIF

if (nloop ge 1000) then begin
                problem = -2
                goto, PROBLEM
endif   

if (redoit eq 1) then GOTO, ITERATE_NONLINEAR

;EVALUATE THE GUESSED MATRIX...
guess_tot, deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc, tfit

resid= tdata- tfit
sigsq = total( resid^2)/(datasize - nparams)
sigma = sqrt( sigsq)
sigarray = sigsq * ssi[indgen(nparams)*(nparams+1)]
indxsqrt = where( sigarray lt 0., countsqrt)
sigarray = sqrt( abs(sigarray))

;stop, 'TEST FOR NEG SQRTS...'

;TEST FOR NEG SQRTS...
if (countsqrt ne 0) then begin
        ;print, countsqrt, ' negative sqrts in sigarray!'
        sigarray[indxsqrt] = -sigarray[indxsqrt]
        problem=-3
        GOTO, PROBLEM
endif

;TEST FOR INFINITIES, ETC...
indxbad = where( finite( a) eq 0b, countbad)
if (countbad ne 0) then begin
        problem=-4
        GOTO, PROBLEM
endif

;DERIVE THE NORMALIZED COVARIANCE ARRAY...
doug = ssi[indgen(nparams)*(nparams+1)]
doug = doug#doug
cov = ssi/sqrt(doug)

;PUT THE UN-PARAMETER-FIXEDUP VARIABLES INTO THE COEFFS ARRAY...
coeffs=[ deltag, epsilon, alpha, phi, chi, psi, qsrc, usrc]
;sigcoeffs= sigarray

;PUT THE ERRORS INTO THE SIGCOEFFS ARRAY...
sigcoeffs= fltarr(8)
nr=-1
ndelt=0
nr= nr+1 & sigcoeffs[ nr]= sigarray[ nr]
nr= nr+1 & sigcoeffs[ nr]= sigarray[ nr]
nr= nr+1 & sigcoeffs[ nr]= sigarray[ nr]
nr= nr+1 & sigcoeffs[ nr]= sigarray[ nr]

if (keyword_set( fixchi) ne 1) then begin
nr= nr+1 & sigcoeffs[ nr]= sigarray[ nr]
endif else ndelt= ndelt+1

if (keyword_set( fixpsi) ne 1) then begin
nr= nr+1 & sigcoeffs[ nr+ ndelt]= sigarray[ nr]
endif else ndelt= ndelt+1

if (keyword_set( fixsrc) ne 1) then begin
nr= nr+1 & sigcoeffs[ nr+ ndelt]= sigarray[ nr]
nr= nr+1 & sigcoeffs[ nr+ ndelt]= sigarray[ nr]
endif

;stop

IF KEYWORD_SET( PARAMETER_FIXUP) THEN BEGIN

;FIRST TAKE CARE OF EPSILON. THIS IS GOOD FOR CIRC OR LIN...
if ( epsilon lt 0) then begin
	epsilon= -epsilon
	phi= phi+ !pi
endif

;NOW DEAL WITH ALPHA. THIS PART ASSUMES NOMINAL LINEAR...
alpha= !dtor* modanglem( !radeg*alpha)
if ( abs( alpha) gt !pi/4.) then begin
    alpha= alpha+ !pi/2. 
    psi= psi+ !pi
    qsrc= -qsrc
    usrc= -usrc  
endif  

phi= !dtor* modangle360( !radeg*phi, /c180)
psi= !dtor* modangle360( !radeg*psi, /c180)
alpha= !dtor* modanglem( !radeg*alpha)

ENDIF

;INSERT QUANS FROM OUTPUT STRUCTURE MUELLERPARAMS1
muellerparams1.deltag= deltag 
muellerparams1.epsilon= epsilon 
muellerparams1.alpha= alpha
muellerparams1.phi= phi
muellerparams1.chi= chi
muellerparams1.psi= psi 

muellerparams1.sigdeltag= sigcoeffs[0]
muellerparams1.sigepsilon= sigcoeffs[1]
muellerparams1.sigalpha= sigcoeffs[2]
muellerparams1.sigphi= sigcoeffs[3]
muellerparams1.sigchi= sigcoeffs[4]
muellerparams1.sigpsi= sigcoeffs[5]

muellerparams1.sigma= sigma
muellerparams1.problem= problem

muellerparams1.qsrc= qsrc
muellerparams1.usrc= usrc
muellerparams1.sigqsrc= sigcoeffs[ 6]
muellerparams1.sigusrc= sigcoeffs[ 7]

m_tot_carl, muellerparams1

;STOP, 'no problem'
return

PROBLEM:

print, 'PROBLEM!! NUMBER ', problem, string(7b)
muellerparams1.problem= problem

;STOP, 'problem'
return
end
