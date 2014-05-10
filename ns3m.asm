;----------------------------------------------------------\
; Copyright (c) 2007, Juan Linietsky, Mukunda Johnson       \-\
;                                                               \
; All rights reserved.                                                   -
;  
; Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
;
;    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
;    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
;    * Neither the name of the owners nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
;CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS              -
;SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.                /
;                                                                        /-/
;-----------------------------------------------------------------------/	

; using WLA DX for assembly: http://www.villehelin.com/

; 1.1 WHAT IS THIS

;=================================================================================
;= ASSEMBLY SWITCHES
;=================================================================================

.DEFINE BANKSWITCHING 1		; NON-ZERO FOR BANKSWITCHING MODE
.DEFINE EXTCHIP 0		; 0 = 

;=================================================================================
;= MEMORY MAPPING
;=================================================================================

.MEMORYMAP
	SLOTSIZE $1000
	DEFAULTSLOT 0
	SLOT 0 $8000
	SLOT 1 $0000 ; zeropage
	SLOT 2 $0200 ; page2
.ENDME    

.ROMBANKSIZE $1000		; 4kb of player code
.ROMBANKS 1

.8BIT

;==================================================================================
;= DEFINITIONS
;==================================================================================

; song data offsets

.define	nsf_sdIT	0
.define	nsf_sdIS	1
.define nsf_sdGV	2
.define	nsf_sdNP	3
.define	nsf_sdNI	4
.define	nsf_sdLN	5
.define	nsf_sdDF	6
.define nsf_sdLOOP	$D
.define nsf_sdvrc6	$19
.define	nsf_sdOT	$100
.define	nsf_sdPAL	$1C8
.define	nsf_sdPAH	$290
.define	nsf_sdPBK	$358
.define	nsf_sdDPCMB	$420
.define	nsf_sdDPCMO	$47C
.define nsf_sdDPCML	$4D8

; channel structure

.define ccs_period	0 ; period	- 16bit
.define ccs_inst	2 ; inst	- 8bit
.define ccs_fx		3 ; effect	- 8bit
.define ccs_param	4 ; param	- 8bit
.define ccs_vol		5 ; volume	- 8bit
.define ccs_fxmem	6 ; fx_mem	- 8bit
.define ccs_note	7 ; note	- 8bit 
.define ccs_perioda	8 ; addition	- 8bit s
.define ccs_vibmode	9 ; vib table	- 8bit
.define ccs_tremode	10; trem table	- 8bit
.define ccs_mute	11; mute	- 8bit b
.define ccs_apuctrl	12; apu control - 8bit b
.define ccs_reserved	13; reserved	- 4byte

; channel flags

.define cflag_pitch	1
.define cflag_start	2
.define cflag_dvol	4

; apu control values:
; 0 = pulse1
; 1 = pulse2
; 2 = triangle
; 3 = noise
; 4 = dpcm
; 5 = vrc6 - pulse1
; 6 = vrc6 - pulse2
; 7 = vrc6 - sawtooth

.define s3m_pattsize	64

;===========================================================================
;= PAGE0 MEMORY
;===========================================================================

.ramsection "NS3M_VAR" BANK 0 SLOT 1

nsm_r1:		db
nsm_r2:		db
nsm_r3:		db
nsm_r4:		db

nsm_tempo:	db		; tempo
nsm_speed:	db		; speed
nsm_volume:	db		; global volume

nsm_position:	db		; song position
nsm_pattread:	dw		; pattern read address
nsm_pattreado:	db		; offset

nsm_tempperiod:	dw
nsm_tempvol:	db

nsm_channels:			; 8 channels
	dsb 128

nsm_nchannels:	db

nsm_pal:	db
nsm_sdad:	dw
nsm_sdOT:	dw
nsm_sdPAL:	dw
nsm_sdPAH:	dw
nsm_sdPBK:	dw
nsm_sdDPCMB:	dw
nsm_sdDPCMO:	dw
nsm_sdDPCML:	dw

nsm_chanp:	db		;

nsm_endrow:	db		; end of row flag

nsm_cflags:	db		; channel flags (&1 = get period/set pitch, &2 = start note, &4 = set default volume, &8 = dont update)

nsm_ploop_row:	db		; MSB = take jump
nsm_ploop_num:	db		
nsm_ploop_adr:	dw

nsm_pdelay:	db

nsm_pjump:	db
nsm_pjumpe:	db
nsm_pjumpr:	db

nsm_chanloop:	db

nsm_playing:	db

nsm_row:	db		; song row position
nsm_tick:	db		; song tick counter
nsm_timer:	db		; song timer (8.8 fixed)
nsm_timersk:	db		; timer skip enable
nsm_timerv:	db		; timer speed LO

nsm_dvar:	db
nsm_dvar2:	db

nsm_apucopyp:	dsb 8
nsm_vrc6copy:	dsb 8

.ENDS

;=================================================================================
;= PAGE2 MEMORY - USED FOR PREVIOUS PARAMETER DATA
;=================================================================================

.ramsection "FX_PREVDATA" BANK 0 SLOT 2

nsm_fxprev:
	dsb 80		; 16 bytes per channel, 2 are reserved

.ends

.define cfxpG	1	; shared with e,f
.define cfxpVS	11	; vibrato-speed
.define cfxpVD	12	; vibrato-depth

;==============================================================================
;= MACROS
;==============================================================================

;==================================================================================
;= NSF VECTORS																						;
;==================================================================================

.ORG $0000
NSF_VECTORS:
	jmp NS3M_PLAY
	jmp NS3M_EVENT

;====================================================
; SWITCHES
;====================================================

NSF_BANKSWITCHING:
	.db BANKSWITCHING		; $86 of NSF
NSF_SPEED:
	.db 0				; 0 = NTSC, 1 = PAL, 2 = DUAL
NSF_STRICTDPCM:
	.db 0
NSF_VERSION:
	.db 101

;====================================================
;= TABLES
;====================================================

NS3M_BPMTABLE:
	.db 0,3,7,10,14,17,20,24,27,31,34,38,41,44,48,51,55,58,61,65,68,72,75,79,82,85,89,92,96,99,102,106,109,113,116,119,123,126,130,133,137,140,143,147,150,154,157,160,164,167,171,174,177,181,184,188,191,195,198,201,205,208,212,215,218,222,225,229,232,236,239,242,246,249,253
NS3M_BPMTABLEp:
	.db 0,4,8,12,16,20,25,29,33,37,41,45,49,53,57,61,66,70,74,78,82,86,90,94,98,102,106,111,115,119,123,127,131,135,139,143,147,152,156,160,164,168,172,176,180,184,188,193,197,201,205,209,213,217,221,225,229,233,238,242,246,250,254,2

.db "/\/\/\/\/"

NS3M_PERIODTABLEH:
	.db 107,101,95,90,84,80,75,71,67,63,60,56,53,50,47,45,42,40,37,35,33,31,30,28,26,25,23,22,21,20,18,17,16,15,15,14,13,12,11,11,10,10,9,8,8,7,7,7,6,6,5,5,5,5,4,4,4,3,3,3,3,3,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
NS3M_PERIODTABLEL:
	.db 3,3,66,2,194,2,130,66,66,129,1,177,129,129,161,1,97,1,193,161,161,192,0,88,192,64,208,128,48,0,224,208,208,224,0,44,96,160,232,64,152,0,112,232,104,240,128,22,176,80,244,160,76,0,184,116,52,248,192,139,88,40,250,208,166,128,92,58,26,252,224,197,172,148,125,104,83,64,46,29,13,254,240,226,214,202,190,180,170,160,151,143,135,127,120,113,107,101,95

NS3M_PERIODTABLE_SAWH:
	.db 122,115,108,102,96,91,86,81,76,72,68,64,61,57,54,51,48,45,43,40,38,36,34,32,30,28,27,25,24,22,21,20,19,18,17,16,15,14,13,12,12,11,10,10,9,9,8,8,7,7,6,6,6,5,5,5,4,4,4,4,3,3,3,3,3,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
NS3M_PERIODTABLE_SAWL:
	.db 77,113,222,222,222,112,75,112,222,148,148,203,38,185,111,111,111,184,38,184,111,74,74,101,147,220,55,183,55,220,147,92,55,37,37,50,73,110,155,219,27,110,201,46,155,18,146,25,165,55,206,110,14,183,101,23,206,137,73,13,210,155,103,55,7,219,178,139,103,69,37,6,233,206,179,155,131,110,89,70,51,34,18,3,245,231,218,206,194,183,173,163,154,145,137,129,122,115,109,

.db "->"
egg:
	.db 0
.db "<-"

NS3M_10s:
	.db 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150

; effect jump table

NS3M_PE_JUMPTABLE:
.dw 	NS3M_FX_UNUSED
.dw	NS3M_FX_SETSPEED
.dw	NS3M_FX_POSITIONJUMP
.dw	NS3M_FX_PATTERNBREAK
.dw	NS3M_FX_VOLUMESLIDE
.dw	NS3M_FX_PORTADOWN
.dw	NS3M_FX_PORTAUP
.dw	NS3M_FX_GLISSANDO
.dw	NS3M_FX_VIBRATO
.dw	NS3M_FX_TREMOR
.dw	NS3M_FX_ARPEGGIO
.dw	NS3M_FX_VIBVOL
.dw	NS3M_FX_PORTAVOL
.dw	NS3M_FX_UNUSED
.dw	NS3M_FX_UNUSED
.dw	NS3M_FX_UNUSED ; OFFSET DISABLED
.dw	NS3M_FX_UNUSED ; PANNING SLIDE?
.dw	NS3M_FX_RETRIG
.dw	NS3M_FX_TREMOLO
.dw	NS3M_FX_EXTENDED
.dw	NS3M_FX_TEMPO
.dw	NS3M_FX_FINEVIBRATO
.dw	NS3M_FX_GLOBALVOL
.dw	NS3M_FX_GLOBALVOLSLIDE
.dw	NS3M_FX_UNUSED ; SET PANNING
.dw	NS3M_FX_UNUSED ; PANBRELLO?

; sine table

NS3M_SINE:
	.db	0,0,1,2,3,3,4,5,5,6,6,7,7,7,7,7,			; depth 1
	.db	0,1,3,4,6,7,8,10,11,12,13,14,14,15,15,15,		; depth 2
	.db	0,2,4,6,9,11,13,15,16,18,19,21,22,22,23,23,		; depth 3
	.db	0,3,6,9,12,15,17,20,22,24,26,28,29,30,31,31,		; depth 4
	.db	0,3,7,11,15,18,22,25,28,30,33,35,36,38,39,39,		; depth 5
	.db	0,4,9,13,18,22,26,30,33,36,39,42,44,45,46,47,		; depth 6
	.db	0,5,10,16,21,26,30,35,39,43,46,49,51,53,54,55,		; depth 7
	.db	0,6,12,18,24,30,35,40,45,49,53,56,58,61,62,63,		; depth 8
	.db	0,6,13,20,27,33,39,45,50,55,59,63,66,68,70,71,		; depth 9
	.db	0,7,15,23,30,37,44,50,56,61,66,70,73,76,78,79,		; depth 10
	.db	0,8,16,25,33,41,48,55,61,67,72,77,80,83,85,86,		; depth 11
	.db	0,9,18,27,36,45,52,60,67,73,79,84,88,91,93,94,		; depth 12
	.db	0,9,19,30,39,48,57,65,73,80,86,91,95,99,101,102,	; depth 13
	.db	0,10,21,32,42,52,61,70,78,86,92,98,102,106,109,110,	; depth 14
	.db	0,11,22,34,45,56,66,75,84,92,99,105,110,114,117,118,	; depth 15

; 1<<x conversion

NS3M_BITS:
	.db %1, %10, %100, %1000, %10000, %100000, %1000000, %10000000

;=================================================================================
;= S3M PLAYER
;=================================================================================

.SECTION "PLAYER"

;-------------------------------------------------------------------
NS3M_PLAY:
;-------------------------------------------------------------------

	; X:00 = NTSC
	; X:01 = PAL
	; A:xx = song#
	; header is in bank1

; setup address tables

	sta	nsm_r1
	and	#1
	asl
	asl
	asl
	adc	#$90
	sta	nsm_sdad+1
	adc	#1			;<----- custom stuff, the increments
	sta	nsm_sdOT+1
	sta	nsm_sdPAL+1
	adc	#1
	sta	nsm_sdPAH+1
	adc	#1
	sta	nsm_sdPBK+1
	adc	#1
	sta	nsm_sdDPCMB+1
	sta	nsm_sdDPCMO+1
	sta	nsm_sdDPCML+1
	
	lda	#0
	sta	nsm_sdad
	lda	#(nsf_sdOT & $FF)
	sta	nsm_sdOT
	lda	#(nsf_sdPAL & $FF)
	sta	nsm_sdPAL
	lda	#(nsf_sdPAH & $FF)
	sta	nsm_sdPAH
	lda	#(nsf_sdPBK & $FF)
	sta	nsm_sdPBK
	lda	#(nsf_sdDPCMB & $FF)
	sta	nsm_sdDPCMB
	lda	#(nsf_sdDPCMO & $FF)
	sta	nsm_sdDPCMO
	lda	#(nsf_sdDPCML & $FF)
	sta	nsm_sdDPCML
	
	lda.w	NSF_SPEED
	beq	+
	cmp	#1
	beq	++
	txa
+
++
	sta nsm_pal						; }
	
; setup banks
	
	lda.w	NSF_BANKSWITCHING	; check if in bankswitching mode
	beq +
	
	lda	nsm_r1
	lsr
	clc
	adc	#1
	sta.w	$5FF9		; song bank address ($9000) = ((song>>1)+1)*4096
	
	lda	#$02
	sta.w	$5FFA
+
	ldy	#nsf_sdIT
	lda	(nsm_sdad),y
	
	jsr	NS3M_SETBPM
	
	ldy	#nsf_sdIS
	lda	(nsm_sdad),y
	sta	nsm_speed
	
	ldy	#nsf_sdGV
	lda	(nsm_sdad),y
	sta	nsm_volume

	ldy	#nsf_sdvrc6
	lda	(nsm_sdad),y
	bmi	+
	lda	#5	; no vrc6, 5 channels
	jmp	++
+	lda	#8	; vrc6 support, 8 channels
++	sta	nsm_nchannels

	lda	#0
	sta	nsm_channels+ccs_apuctrl
	lda	#2
	sta	nsm_channels+ccs_apuctrl+16
	lda	#4
	sta	nsm_channels+ccs_apuctrl+32
	lda	#6
	sta	nsm_channels+ccs_apuctrl+48
	lda	#8
	sta	nsm_channels+ccs_apuctrl+64
	lda	#10
	sta	nsm_channels+ccs_apuctrl+80
	lda	#12
	sta	nsm_channels+ccs_apuctrl+96
	lda	#14
	sta	nsm_channels+ccs_apuctrl+112

	ldy	#0
	sty	nsm_position
	lda	(nsm_sdOT),y
	
	tay
	
	jsr	NS3M_SETPATTERN
	
	lda	#255
	sta	nsm_playing
	
; turn on nes sound
	
	lda	#%1111
	sta	$4015

; activate breaker egg
	
	lda.w egg
	beq +
	lda #%10110111
	jmp ++
+
	lda #%1000
++
	sta.w $4001
	sta.w $4005
	
	rts
	
;-----------------------------------------------------------------------
NS3M_SETPATTERN:				; (70 cycles)
;-----------------------------------------------------------------------

	; y = pattern index

	lda.w	NSF_BANKSWITCHING	; check bankswitching mode
	bne	+
	lda	(nsm_sdPBK), y		;   get bank
	asl				;   multiply
	asl
	asl
	asl
	adc	#$80			;   add (clears carry too)
	jmp	++				;   skip other section
+					; switched mode:
	lda	#$A0			; fixed bank
	clc				; clear carry
++
	adc	(nsm_sdPAH), y		; add hi address
	sta	nsm_pattread+1		; store 
	lda	(nsm_sdPAL), y		; get low address
	sta	nsm_pattread		; store
	
	lda.w	NSF_BANKSWITCHING	; set bank#
	beq	+
	lda	(nsm_sdPBK), y
	sta.w	$5FFA
	clc
	adc	#1
	sta.w	$5FFB
+
	
	lda	#0			; clear row
	sta	nsm_row
	sta	nsm_tick		; &tick

	sta	nsm_ploop_num		; &pattern loop
	sta	nsm_ploop_row
	sta	nsm_ploop_adr
	sta	nsm_ploop_adr+1
	rts				; return

;-----------------------------------------------------------------------------
NS3M_SETBPM:					; 44 cycles
;-----------------------------------------------------------------------------

	; a = bpm
	; timer = 60hz NTSC, 50hz PAL
	
	sta nsm_tempo		; save tempo
	
	tay			; temporary save
	lda nsm_pal		; check PAL mode
	bne ++			; jump to PAL if set
	tya			; restore

	ldy #0			; load 0
;	sty nsm_timer		; nsm_timer=0		; this should be done at startup
	cmp #150		; check if bpm > 150
	bcc +
	ldy #255		; if so enable tick skip
	sbc #150		; bpm = bpm MOD 150
+
	lsr			; divide tempo/2
	sty nsm_timersk		; save timer skip value (set if bpm over 150)
	tay			; y = bpm address
	lda.w NS3M_BPMTABLE, y	; get (bpm/150) *256: .8 fixed
	sta nsm_timerv		; store value

	rts			; return

++
	tya			; pal mode
	ldy #0
	sty nsm_timer
	cmp #125
	bcc +
	ldy #255
	sbc #125
+
	lsr
	sty nsm_timersk
	tay
	lda.w NS3M_BPMTABLEp, y		; uses different table
	sta nsm_timerv
	rts

;-----------------------------------------------------------------------------
NS3M_EVENT:
;-----------------------------------------------------------------------------
	
	bit	nsm_playing		;
	bpl	++
	lda	nsm_timer		; load timer
	clc				; prepare addition
	adc	nsm_timerv		; add timer speed
	sta	nsm_timer		; store
	bcc	+			; check for overflow
	jsr	NS3M_MAIN		; process tick
+	
	bit	nsm_timersk		; check for timer hi value
	bpl	+			; 
	jmp	NS3M_MAIN		; process tick (regular jump, uses other return)
+	
++
	rts				; return
	
;-----------------------------------------------------------------------------
NS3M_MAIN:
;-----------------------------------------------------------------------------

	ldx	#0			; reset variables		{ 16 cycles
	stx	nsm_chanp
	stx	nsm_endrow
	stx	nsm_pattreado
	lda	nsm_nchannels		; set loop counter
	sta	nsm_chanloop		;				}
	
_nm_chanloop:				; 270 cycles FIRST, 16 cycles OTHER
	lda	#0			; reset flags			{ 14 cycles
	sta	nsm_cflags		;
	
	ldy	nsm_pattreado		; fetch offset

	lda	nsm_pdelay		; check pattern delay		{ 25 cycles
	beq	+			; zero?
	bmi	+
	lda	#255			; skip if delayed
	sta	nsm_endrow
	jmp	_nm_othertick
+
	
	lda	nsm_tick		; check tick
	beq	+			; skip pattern read on !0
	jmp	_nm_othertick
+
	
; first tick							}
; read pattern
	
	bit	nsm_endrow		; check end row flag
	bpl	+			;
	jmp	_nm_pattr_skipchan	; skip section if set
+					;
	
	lda	(nsm_pattread), y	; load byte
	
	bne	+			; check for ending row
	iny				;
	lda	#255			; end row
	sta	nsm_endrow		;
	jmp	_nm_pattr_skipchan
+
	and	#31			; compare with channel
	cmp	nsm_chanp				
	bne	_nm_pattr_skipchan	; skip if no match
	
	lda	(nsm_pattread), y	; channel ok, read byte						{ 16 cycles
	iny				; increase offset
	
	rol				; rotate effect+param
	rol				; rotate volume
	rol				; rotate note+inst, carry=note+inst
	sta	nsm_r1			; save bits							}

	bcc	_nm_pattr_skipnote	; note+inst, if carry=true, note+inst exist		{ 65 cycles*
	lda	(nsm_pattread), y	; read note
	iny					; increase offset
	cmp	#255				; check for empty note
	beq	+				; skip if empty
	cmp	#254				; check for note-off
	bne	++				; yes?
	lda	#0				; then load volume with zero
	sta	nsm_channels+ccs_vol, x
	iny
	jmp	_nm_pattr_skipnote		; skip section
++						; no:

	pha					; translate note
	and	#$F0				; octave * 12
	lsr					;
	sta	nsm_r2				;
	lsr					;
	clc					;
	adc	nsm_r2				;
	sta	nsm_r2				;
	pla					; +note
	and	#$0F				;
	adc	nsm_r2				;
	
	sta	nsm_channels+ccs_note,x		; save note
	lda	nsm_cflags			; set pitch flag
	ora	#1
	sta	nsm_cflags
	lda	#0
	sta	nsm_channels+ccs_fxmem, x	; reset fx memory
+
	lda	(nsm_pattread), y		; read instrument
	iny					; increase offset
	cmp	#0				; 0 == --
	beq	_nm_pattr_skipnote		; skip if 0
	sta	nsm_channels+ccs_inst, x	; save instrument
	lda	nsm_cflags			; set flags
	ora	#cflag_start|cflag_dvol
	sta	nsm_cflags
_nm_pattr_skipnote:				;	
	
	lsr	nsm_r1				; shift bits, carry=vol bit
	bcc	+				; skip if cleared
	lda	(nsm_pattread), y		; read volume
	iny					; increase pointer
	sta	nsm_channels+ccs_vol, x		; store volume
	lda	nsm_cflags			; remove default volume flag
	and	#255-cflag_dvol
	sta	nsm_cflags	
+						;
	lsr	nsm_r1				; shift bits, carry=effect+param
	bcc	_nm_pattr_nofx			; skip if cleared
	lda	(nsm_pattread), y			; read effect
	iny					; increase offset
	sta	nsm_channels+ccs_fx, x		; store effect
	
	lda	(nsm_pattread), y			; read param
	iny					; increase offset
	sta	nsm_channels+ccs_param, x		; store param
	jmp	_nm_pattr_isfx			; skip other section
_nm_pattr_nofx:					; no effect?				<--- jump to here instead
	lda	#0				; reset effect+param
	sta	nsm_channels+ccs_fx, x
	sta	nsm_channels+ccs_param, x
_nm_pattr_isfx:
	
	jmp	_nm_pattr_hasdata		; skip section below
_nm_pattr_skipchan:				; no data?
	lda	#0				; reset effect+param			<--- CHANGE THIS TO CODE ABOVE
	sta	nsm_channels+ccs_fx, x		
	sta	nsm_channels+ccs_param, x
_nm_pattr_hasdata:

	sty	nsm_pattreado			; save offset			{ 61 cycles 
	
	lda	#cflag_pitch			; check pitch flag
	bit	nsm_cflags
	beq	+				; skip if cleared
	
	lda	nsm_channels+ccs_fx, x		; check effect for glissando
	cmp	#7 	; Gxx			; skip if so
	beq	+
	cmp	#12	; Lxx
	beq	+
	ldy	nsm_channels+ccs_note, x	; read note

	jsr	NS3M_GETPERIOD			; get period
	sta	nsm_channels+ccs_period, x	; save period, 16-bits
	sty	nsm_channels+ccs_period+1, x
+						;				}
	
	lda	#cflag_dvol			; check dvol flag		{ 26 cycles 
	bit	nsm_cflags			;
	beq	+				; skip if cleared
	lda	nsm_channels+ccs_inst,x		; fetch instrument#
	cmp	#8
	bcc	++
	lda	#64
	sta	nsm_channels+ccs_vol, x
	jmp	+
++
	adc	#(nsf_sdDF-1)			; translate to default volume address
	tay					; send to index
	lda	(nsm_sdad), y			; load value
	sta	nsm_channels+ccs_vol, x		; store
+						;				}

	jmp	_nm_processfx			; process effects
	
_nm_othertick:
	
	; do stuff that other ticks require?
	
_nm_processfx:

;------------------------------------------------------------------------------------------;

	jsr NS3M_COPYTEMP			; copy temporary values				26+5

	jsr NS3M_PROCESSEFFECT			; process effects				300 cycles

	jsr NS3M_CH_UPDATEAPU			; update apu state				97.6 cycles
	
_nm_nextchan:
	txa					; increment channel offset, 16 bytes per channel	{ 23 cycles
	clc
	adc	#16
	tax
	inc	nsm_chanp			; increase channel#
	dec	nsm_chanloop			; decrease loop#
	beq	_nm_endtick			; exit if zero
	jmp	_nm_chanloop			; loop													}
_nm_endtick:

	lda	nsm_tick			; read tick
	bne	++				; skip if non-zero
	bit	nsm_endrow			; check if endrow is set
	bmi	++
	inc	nsm_pattreado			; skip the endrow byte that we missed
++
	clc					; ready for addition
	lda	nsm_pattreado			; add pattern offset to pattread
	adc	nsm_pattread
	sta	nsm_pattread
	lda	nsm_pattread+1
	adc	#0
	sta	nsm_pattread+1

; increment tick/row/position
	
	inc	nsm_tick
	lda	nsm_tick
	cmp	nsm_speed	; tick >= speed?
	bcs	+
	rts			; no: return
+

; reset tick
; & increment row

	lda	#0
	sta	nsm_tick

; check pattern delay

	lda	nsm_pdelay
	beq	+
	and	#127		; clear flag
	sta	nsm_pdelay	;
	dec	nsm_pdelay	; decrease counter
	beq	+		; 0? then proceed normally
	rts			; otherwise quit
+

; check for pattern loop

	bit	nsm_ploop_row	; msb = enable
	bpl	+

	lda	nsm_ploop_row	; read row#
	and	#63		; clear jump bit
	sta	nsm_row		; set row
	sta	nsm_ploop_row	; save copy
	lda	nsm_ploop_adr	; set pattern address
	sta	nsm_pattread
	lda	nsm_ploop_adr+1
	sta	nsm_pattread+1
	rts			; exit
+

; check for position jump

	bit	nsm_pjumpe
	bpl	+
	lda	#0		; reset boolean
	sta	nsm_pjumpe
	lda	nsm_pjump	; read order#
-
	ldy	#nsf_sdLN	; check if > length of song
	cmp	(nsm_sdad),y	; lots of checking...
	bcc	++
	lda	#0
++
	sta	nsm_position
	tay
	lda	(nsm_sdOT),y

	cmp	#$FF		; handle "end" marker
	bne	++
	iny
	tya
	jmp	-
++

	tay			; y = position

	jsr	NS3M_SETPATTERN
	lda	nsm_pjumpr	; set row#
	sta	nsm_row
	sta	nsm_r1		; fastforward to row#
	beq	++		; (skip if 0)

	jsr	NS3M_FASTFORWARD
++
	lda	#0		; reset boolean
	sta	nsm_pjumpr	; clear position jump variable
	rts
+
	
	clc			; increment row
	lda	nsm_row
	adc	#1
	
	cmp	#s3m_pattsize
	bcc	+		; <64? skip to exit section
	ldy	nsm_position	; increment song position
	iny
	sty	nsm_position
-
	tya			; { check for end of song/song divider
	sty	nsm_r1
	ldy	#nsf_sdLN
	cmp	(nsm_sdad),y
	bcc	++
	ldy	#0
	sty	nsm_position
	jmp	+++
++
	ldy	nsm_r1
+++
	
	lda	(nsm_sdOT),y	; get pattern# from order table
	cmp	#$FF		; WHAT IS THIS??? 1.1
	bne	++
	iny
	jmp	-
++				; }
	
	tay			; transfer to index
	jmp	NS3M_SETPATTERN	; set pattern, dont set return address
+
	sta	nsm_row		; save row#

	rts			; exit

;--------------------------------------------------------------
NS3M_COPYTEMP:		 	; 26 cycles
;--------------------------------------------------------------

	lda	nsm_channels+ccs_vol, x		; copy channel varaibles to temporary values
	sta	nsm_tempvol
	lda	nsm_channels+ccs_period, x
	sta	nsm_tempperiod
	lda	nsm_channels+ccs_period+1, x
	sta	nsm_tempperiod+1
	lda	nsm_cflags
	ora	#cflag_pitch
	sta	nsm_cflags
	rts

;--------------------------------------------------------------
NS3M_GETPERIOD:			; 22 cycles
;--------------------------------------------------------------

	cpx	#112
	bcs	_sawtooth_period

	; y = note
	lda.w	NS3M_PERIODTABLEL, y
	pha
	lda.w	NS3M_PERIODTABLEH, y
	tay
	pla
	rts

_sawtooth_period:

	lda.w	NS3M_PERIODTABLE_SAWL, y
	pha
	lda.w	NS3M_PERIODTABLE_SAWH, y
	tay
	pla
	rts

;==================================================================================
;= EFFECT PROCESSING
;==================================================================================

; parameter memory control

ns3m_pmemtable:
.db	0,0,0,0,1,2,2,2,0,4,5,1,1,0,0,6,0,7,8,9,10, 0,0,11,0,0,0
;	/,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s, t, u,v, w,x,y,z

; h/u are handled in their routines

;--------------------------------------------------------------
NS3M_EXCHANGEPARAMETER:
;--------------------------------------------------------------

; exchange parameter memory (when 0)
	
	ldy	nsm_channels+ccs_fx, x
	lda	ns3m_pmemtable, y
	sec
	sbc	#1
	bmi	+	; 0 = effect doesn't have memory / handled by routine

	stx	nsm_r1	; add channel offset
	clc
	adc	nsm_r1
	tay

	lda	nsm_channels+ccs_param, x
	beq	++
	sta.w	nsm_fxprev, y
	rts

++	lda.w	nsm_fxprev, y
	sta	nsm_channels+ccs_param, x
	
+	rts

;--------------------------------------------------------------
NS3M_PROCESSEFFECT:
;--------------------------------------------------------------

	; x = chan offset
	
	jsr	NS3M_EXCHANGEPARAMETER
	
	lda	nsm_channels+ccs_fx, x
	asl
	tay
	lda.w	NS3M_PE_JUMPTABLE, y
	sta	nsm_r1
	lda.w	NS3M_PE_JUMPTABLE+1, y
	sta	nsm_r2
	lda	nsm_channels+ccs_param, x
	ldy	nsm_tick
	jmp	(nsm_r1)

; NOTICE
; Y = TICK#
; A = PARAM
; Z FLAG = TICK0

;-------------------------------------------------------------------------------------------------
NS3M_FX_SETSPEED:		; Axx - Set Speed
;---------------------------------------------------------------------------------------------

; speed = parameter on tick0

	bne	+
	sta	nsm_speed
+	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_POSITIONJUMP:		; Bxx - Position Jump
;-------------------------------------------------------------------------------------------------

; on tick0 setup a postition jump

	bne	+
	sta	nsm_pjump
	lda	#128
	sta	nsm_pjumpe
+	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_PATTERNBREAK:		; Cxx - Pattern Break
;-------------------------------------------------------------------------------------------------

; on tick0 setup a pattern break

	bne	+
	and	#$0F
	sta	nsm_pjumpr
	lda	nsm_channels+ccs_param, x
	lsr
	lsr
	lsr
	lsr
	tay
	lda.w	NS3M_10s, y
	clc
	adc	nsm_pjumpr
	sta	nsm_pjumpr
	
	lda	nsm_position
	sec
	adc	#0
	sta	nsm_pjump
	lda	#128
	sta	nsm_pjumpe
+	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_VOLUMESLIDE:				; Dxx - Volume Slide
;-------------------------------------------------------------------------------------------------

; slide volume...
	pha
	lda	nsm_tempvol
	sta	nsm_r1
	pla

	jsr	NS3M_VOLSLIDE

	sta	nsm_tempvol
	sta	nsm_channels+ccs_vol,x

ns3m_coolexit:
	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_PORTADOWN:				; Exx - Portamento Down
NS3M_FX_PORTAUP:				; Fxx - Portamento Up
;-------------------------------------------------------------------------------------------------
	
	cmp	#$F0				; > $F0 ?
	bcc	+				; if not, skip this section
	ldy	nsm_tick			; if so, this is fine portamento
	bne	ns3m_coolexit			; only update on tick0
	and	#$0F				; mask paramter
	jmp	++				; skip section below (y=0 too)
+
	cmp	#$E0				; check for extra-fine mode
	bcc	+				; skip if not
	ldy	nsm_tick			; extra fine: dont update on other ticks
	bne	ns3m_coolexit		
	and	#$0F				; mask paramter
	sty	nsm_r1				; clear higher amount (y=0)
	jmp	+++				; jump to slide (skip *4)
+
	ldy	nsm_tick			; dont update on t0, regular portamento
	beq	ns3m_coolexit

	ldy	#0				; clear r1 (for shifting)
++
	sty	nsm_r1				; 
	asl					; multiply parameter by 4
	rol	nsm_r1
	asl
	rol	nsm_r1
+++
	pha					; save param
	lda	nsm_channels+ccs_fx, x		; check which way to slide
	cmp	#5				; Exx
	beq	+				; slide down?
	pla					; restore param
	jmp	NS3M_CH_PSD			; slide period
+
	pla					; restore param
	jmp	NS3M_CH_PSU			; slide period

;-------------------------------------------------------------------------------------------------
NS3M_FX_GLISSANDO:				; Gxx - Glissando
;-------------------------------------------------------------------------------------------------
	
	beq	ns3m_coolexit			; dont update on t0
	
	ldy	nsm_channels+ccs_note, x	; get note
	jsr	NS3M_GETPERIOD			; get period
	sta	nsm_r3				; save period
	sty	nsm_r4
	lda	nsm_channels+ccs_period+1,x	; load period
	cmp	nsm_r4				; check direction
	beq	_ns3m_fxg_checklo

	lda	#0				; etc, etc...
	sta	nsm_r1
	lda.w	nsm_fxprev+cfxpG,x
	
	
	bcs	_ns3m_fxg_high			; slide pitch
	bcc	_ns3m_fxg_low
	
_ns3m_fxg_checklo:
	lda	nsm_channels+ccs_period,x
	cmp	nsm_r3
	beq	_ns3m_fxg_exit
	
	lda	#0
	sta	nsm_r1
	lda.w	nsm_fxprev+cfxpG,x
	
	bcs	_ns3m_fxg_high
_ns3m_fxg_low:
	
	asl
	rol	nsm_r1
	asl
	rol	nsm_r1
	jsr	NS3M_CH_PSU
	
	lda	nsm_channels+ccs_period+1,x
	cmp	nsm_r4
	beq	+
	bcs	_ns3m_fxg_clip
	jmp	_ns3m_fxg_exit
+
	lda	nsm_channels+ccs_period,x
	bcs	_ns3m_fxg_clip
	jmp	_ns3m_fxg_exit
	
_ns3m_fxg_high:
	
	asl
	rol	nsm_r1
	asl
	rol	nsm_r1
	jsr	NS3M_CH_PSD
	
	lda	nsm_channels+ccs_period+1,x
	cmp	nsm_r4
	beq	+
	bcc	_ns3m_fxg_clip
	jmp	_ns3m_fxg_exit
+
	lda	nsm_channels+ccs_period,x
	cmp	nsm_r3
	bcs	_ns3m_fxg_exit
	
_ns3m_fxg_clip:
	lda	nsm_r3
	sta	nsm_channels+ccs_period,x
	
	lda	nsm_r4
	sta	nsm_channels+ccs_period+1,x
	
_ns3m_fxg_exit:
	lda	nsm_channels+ccs_period,x
	sta	nsm_tempperiod
	lda	nsm_channels+ccs_period+1,x
	sta	nsm_tempperiod+1
	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_VIBRATO:			; Hxx - Vibrato
;-------------------------------------------------------------------------------------------------

; special memory handling

	beq	+		; on tick0 :
	and	#$0F
	beq	++
	sta.w	nsm_fxprev+cfxpVD, x	; store depth*1
	; depth&128 = fine flag

++	lda	nsm_channels+ccs_param,x
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	beq	++
	sta.w	nsm_fxprev+cfxpVS, x	; store speed*1
++
+
	
;------------------------------------------------------------
NS3M_FX_VIBRATO2:		; Kxx/Uxx entry
;------------------------------------------------------------
	
	ldy	nsm_tick
	beq	_ns3mfxv_exit2		; dont update on t0
	lda.w	nsm_fxprev+cfxpVS, x	; get speed
	clc					; ready for addition
	adc	nsm_channels+ccs_fxmem, x	; add to sine position
	and	#63				; wrap value
	sta	nsm_channels+ccs_fxmem, x	; save value
	sta	nsm_r1				; save value
	lda.w	nsm_fxprev+cfxpVD, x		; get paramter
	bpl	_vib_normal
	
	and	#127
	jsr	NS3M_GETVTABLE			; get vibrato value
	cmp	#0				; set processor status
	php					; save status
	lsr					; shift value
	lsr
	plp					; restore status
	bpl +					; sign-extend if value was negative
	ora #%11000000				; 
+	jmp	_vib_fine			; (value /= 4)
_vib_normal:
	jsr	NS3M_GETVTABLE			; get vibrato value
_vib_fine:

+	cmp #0					; positive/negative?
	bmi +					; jump to area
	clc					; ready for addition
	
	adc	nsm_tempperiod			; add values to temporary period
	sta	nsm_tempperiod
	lda	nsm_tempperiod+1
	adc	#0
	sta	nsm_tempperiod+1
	
	jmp	_nmfxv_exit			; exit
+
	clc					; negate value
	eor	#255
	adc	#1
	sec					; ready for subtraction
	
	sta	nsm_r1				; subtract values, the lazy way
	lda	nsm_tempperiod
	sbc	nsm_r1
	sta	nsm_tempperiod
	lda	nsm_tempperiod+1
	sbc	#0
	sta	nsm_tempperiod+1
	
_nmfxv_exit:
	lda	nsm_cflags			; set PITCH flag
	ora	#cflag_pitch
	sta	nsm_cflags

	rts					; return

_ns3mfxv_exit2:
	lda	nsm_cflags
	and	#255-cflag_pitch
	sta	nsm_cflags
	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_TREMOR:					; Ixx - Tremor
;-------------------------------------------------------------------------------------------------
	
	lda	nsm_channels+ccs_fxmem, x

	; fxmem:
	; vxxxtttt
	;  v = volume on/off (boolean)
	;  t = ticks remaining
	
	bmi	_nmfxt_on
_nmfxt_off:
	bne	_nmfxt_dec
	lda	#0
	sta	nsm_channels+ccs_mute, x
	lda	nsm_channels+ccs_param, x
	lsr
	lsr
	lsr
	lsr
	ora	#128
	
	jmp	_nmfxt_store
_nmfxt_on:
	cmp	#128
	bne	_nmfxt_decc
	lda	#1
	sta	nsm_channels+ccs_mute, x
	lda	nsm_channels+ccs_param, x
	and	#$0F
	jmp	_nmfxt_store

_nmfxt_dec:
	sec
_nmfxt_decc:	; <-- carry set
	sbc	#1
_nmfxt_store:
	sta	nsm_channels+ccs_fxmem, x
	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_ARPEGGIO:				; Jxx - Arpeggio
;-------------------------------------------------------------------------------------------------

; arpeggio, yey!

	lda	nsm_channels+ccs_fxmem, x
	beq	_nmfxa_zero
	cmp	#1
	beq	_nmfxa_one
_nmfxa_two:
	lda	#0
	sta	nsm_channels+ccs_fxmem, x
	lda	nsm_channels+ccs_param, x
	and	#$F
	jmp	_nsmfxa_set
_nmfxa_zero:
	inc	nsm_channels+ccs_fxmem, x
	lda	#0
	jmp	_nsmfxa_set
_nmfxa_one:
	inc	nsm_channels+ccs_fxmem, x
	lda	nsm_channels+ccs_param, x
	lsr
	lsr
	lsr
	lsr
	
_nsmfxa_set:
	
	clc
	adc	nsm_channels+ccs_note, x
	tay
	jsr	NS3M_GETPERIOD
	sta	nsm_tempperiod
	sty	nsm_tempperiod+1
	lda	nsm_cflags
	ora	#cflag_pitch
	sta	nsm_cflags
	
	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_VIBVOL:					; Kxx - Vibrato + Volume Slide
;-------------------------------------------------------------------------------------------------

	jsr NS3M_FX_VIBRATO2			; do vibrato		5+155
	jmp NS3M_FX_VOLUMESLIDE			; do volume slide	3+52

;-------------------------------------------------------------------------------------------------
NS3M_FX_PORTAVOL:				; Lxx - Glissando + Volume Slide
;-------------------------------------------------------------------------------------------------

	jsr NS3M_FX_GLISSANDO 		; do glissando    5+188
	jmp NS3M_FX_VOLUMESLIDE		; do volume slide 3+52

;-------------------------------------------------------------------------------------------------
NS3M_FX_RETRIG:					; Qxx - Retrigger Note
;-------------------------------------------------------------------------------------------------

	; not much use with chips...
	rts

;-------------------------------------------------------------------------------------------------
NS3M_FX_TREMOLO:				; Rxx - Tremolo
;-------------------------------------------------------------------------------------------------

	beq	_nmfxtr_t0			; dont update on t0	
	lda	nsm_channels+ccs_param, x
	lsr
	lsr
	lsr
	lsr											; COPY
	clc
	adc	nsm_channels+ccs_fxmem, x
	cmp	#64
	bcc	+
	sbc	#64
+
	sta	nsm_channels+ccs_fxmem, x											; COPY
	sta	nsm_r1
_nmfxtr_t0_entry:
	lda	nsm_channels+ccs_param, x
	and	#$0F
	
	jsr	NS3M_GETVTABLE
	
	cmp	#128
	bcs	+											; COPY

	lsr
	lsr	;;;	
	
	clc
	adc	nsm_tempvol
	cmp	#64
	bcc	++
	lda	#64
++
	sta	nsm_tempvol
	rts
+											; COPY
	eor	#255
	adc	#0			; (carry set)
	lsr
	lsr		;;;
	sec
	sta	nsm_r1
	lda	nsm_tempvol
	sbc	nsm_r1
	bcs	++

	lda	#0
++
	sta	nsm_tempvol
_nmfxtr_exit:
	rts

_nmfxtr_t0:
	lda	nsm_channels+ccs_fxmem, x
	sta	nsm_r1
	jmp	_nmfxtr_t0_entry

;-------------------------------------------------------------------------------------------------
NS3M_FX_TEMPO:					; Txx - Tempo / Slide
;-------------------------------------------------------------------------------------------------

	cmp	#$10		; param < $10 == slide down
	bcc	_nfx_tempo_down
	cmp	#$20		; param < $20 == slide up
	bcc	_nfx_tempo_up

	dey			; on tick0, y will be -1
	bpl	+

	jmp	NS3M_SETBPM
+
	rts

_nfx_tempo_down:
	and	#$0F
	sta	nsm_r1

	lda	nsm_tempo
	sbc	nsm_r1
	bcs	+
-
	lda	#32
+
	cmp	#32
	bcc	-
	jmp	NS3M_SETBPM

_nfx_tempo_up:
	and	#$0F
	adc	nsm_tempo
	bcc	+
	lda	#255
+
	jmp	NS3M_SETBPM

;-------------------------------------------------------------------------------------------------
NS3M_FX_FINEVIBRATO:			; Uxx - Fine Vibrato
;-------------------------------------------------------------------------------------------------

; special memory handling

	beq	+		; on tick0 :
	and	#$0F
	beq	++
	ora	#128
	sta.w	nsm_fxprev+cfxpVD, x	; store depth*1 | 128
	; depth&128 = fine flag

++	lda	nsm_channels+ccs_param,x
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	beq	++
	sta.w	nsm_fxprev+cfxpVS, x	; store speed*1
++
+
	jmp	NS3M_FX_VIBRATO2

;-------------------------------------------------------------------------------------------------
NS3M_FX_GLOBALVOL:			; Vxx - Set Global Volume
;-------------------------------------------------------------------------------------------------

	bne +				; dont update on t0
	lda nsm_channels+ccs_param, x
	sta nsm_volume
+
	rts
;-------------------------------------------------------------------------------------------------
NS3M_FX_GLOBALVOLSLIDE:			; Wxx - Global Volume Slide
;-------------------------------------------------------------------------------------------------

	pha
	lda	nsm_volume
	sta	nsm_r1
	pla

	jsr	NS3M_VOLSLIDE

	sta	nsm_volume
	rts

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; Sxy EXTENDED EFFECTS
;-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

NS3M_FXX_TABLE:
.dw	NS3M_FXX_UNUSED			; S0x set amiga filter		NOT IMPLEMENTED
.dw	NS3M_FXX_UNUSED			; S1x glissando control		NOT IMPLEMENTED
.dw	NS3M_FXX_UNUSED			; S2x set finetune		NOT IMPLEMENTED
.dw	NS3M_FXX_UNUSED			; S3x vibrato waveform		NOT IMPLEMENTED
.dw	NS3M_FXX_UNUSED			; S4x tremolo waveform		NOT IMPLEMENTED
.dw	NS3M_FXX_UNUSED			; S5x
.dw	NS3M_FXX_UNUSED			; S6x
.dw	NS3M_FXX_UNUSED			; S7x
.dw	NS3M_FXX_UNUSED			; S8x set panning		NOT IMPLEMENTED
.dw	NS3M_FXX_UNUSED			; S9x
.dw	NS3M_FXX_UNUSED			; SAx old stereo channel	NOT IMPLEMENTED
.dw	NS3M_FXX_PATTERNLOOP		; SBx pattern loop
.dw	NS3M_FXX_NOTECUT		; SCx note cut
.dw	NS3M_FXX_NOTEDELAY		; SDx note delay
.dw	NS3M_FXX_PATTERNDELAY		; SEKS pattern delay
.dw	NS3M_FXX_UNUSED			; SFx funk repeat		NOT IMPLEMENTED

;-----------------------------------------------------------------------------------------------

NS3M_FX_EXTENDED:
	
	lsr
	lsr
	lsr
	and	#$FE
	tay
	lda	NS3M_FXX_TABLE, y
	sta	nsm_r1
	lda	NS3M_FXX_TABLE+1, y
	sta	nsm_r2
	lda	nsm_channels+ccs_param, x
	and	#$0F
	ldy	nsm_tick
	jmp	(nsm_r1)

;-----------------------------------------------------------------------------------------------
NS3M_FXX_PATTERNLOOP:				; SBx - Pattern Loop
;-----------------------------------------------------------------------------------------------

	bne	_nsfxx_pl_exit

	and	#$0F
	bne	+

; zero value
; note down current pattern address

	lda	nsm_pattread
	sta	nsm_ploop_adr
	lda	nsm_pattread+1
	sta	nsm_ploop_adr+1

; and row

	lda	nsm_row
	sta	nsm_ploop_row
	rts
+

; other values:
; check loop count, and reset/decrement

	ldy	nsm_ploop_num
	bne	+
	sta	nsm_ploop_num	; a = param --^
	tay
	iny
+
	
	dey
	sty	nsm_ploop_num
	sty	nsm_dvar
	beq	+
	lda	nsm_ploop_row
	ora	#128
	sta	nsm_ploop_row
_nsfxx_pl_exit:
	rts

;-----------------------------------------------------------------------------------------------
NS3M_FXX_NOTECUT:				; SCx - Note Cut
;-----------------------------------------------------------------------------------------------

; on tick0, compare param with tick

	beq	+
	cmp	nsm_tick
	bne	+

; if == then clear volume to 0

	lda	#0
	sta	nsm_channels+ccs_vol, x
	sta	nsm_tempvol
+	rts

;-----------------------------------------------------------------------------------------------
NS3M_FXX_NOTEDELAY:				; SDx - Note Delay
;-----------------------------------------------------------------------------------------------

	bne	+
	lda	nsm_cflags
	sta	nsm_channels+ccs_fxmem, x
	jmp	++

+	cmp	nsm_tick
	bne	++
	lda	nsm_channels+ccs_fxmem, x
	sta	nsm_cflags
	rts
++
	lda	#8
	sta	nsm_cflags
	rts

;-----------------------------------------------------------------------------------------------
NS3M_FXX_PATTERNDELAY:				; SEKS - Pattern Delay
;-----------------------------------------------------------------------------------------------

	bne +
	ldy nsm_pdelay
	bne +
	clc
	adc #1

	ora #128
	sta nsm_pdelay

+

;----------------------------------------------------------------------------
NS3M_FXX_UNUSED:				; S?x - Unused
NS3M_FX_UNUSED:					; ?xx - Unused
;----------------------------------------------------------------------------

	rts

;----------------------------------------------------------------------------
NS3M_VOLSLIDE:
;----------------------------------------------------------------------------

; slides volume...
; param may have special behavior
; r1 = volume
; a = slide value
; will clamp to 0->64

; returns a = value

	sta	nsm_r2				; save parameter
	cmp	#$F0				; check if = $F0
	beq	+++				; jump to slide (up 15)
	and	#$F0				; check for fine slide
	beq	_ns3m_vsd_normal		; jump to normal slide (down)
	cmp	#$F0				; check for fine slide
	beq	_ns3m_vsd_fine			; jump to fine slide (down)
	
+++	; increase volume
	
	lda	nsm_r2				; get parameter
	and	#$0F				; mask low nibble
	cmp	#$0F				; check for fine slide
	bne	+								
	lda	nsm_tick			; dont slide on t0
	bne	_ns3m_vs_exitN			; dont slide on t0
	jmp	++				; jump to slide
+	
	lda	nsm_tick
	beq	_ns3m_vs_exitN
++
	lda	nsm_r2				; get param
	lsr					; hi nibble
	lsr
	lsr
	lsr
	clc					; ready for addition
	adc	nsm_r1				; add to volume
	cmp	#64				; clamp
	bcc	+
	lda	#64
+	rts					; return
	
_ns3m_vsd_fine:					; -fine
	lda	nsm_tick			; dont slide on other ticks
	bne	_ns3m_vs_exitN
	jmp	+				; jump to slide
_ns3m_vsd_normal:				; -normal
	lda	nsm_tick			; dont slide on t0
	beq	_ns3m_vs_exitN
+
	lda	nsm_r2				; get param
	and	#$0F				; mask lo nibble
	sta	nsm_r2				; store
	
	; decrease volume
	lda	nsm_r1				; subtract from volume
	sec
	sbc	nsm_r2
	bcs	_ns3m_vs_exit			; prevent overflow
	lda	#0

_ns3m_vs_exit:
	rts					; return
_ns3m_vs_exitN:
	lda	nsm_r1
	rts

;-----------------------------------------------------------------------------------
NS3M_CH_PSU:			; 42 cycles
;-----------------------------------------------------------------------------------

; channel period slide up, 16bit
; a = amount.LO
; r1= amount.HI
; x = c offset
	
	clc
	adc	nsm_channels+ccs_period, x
	sta	nsm_channels+ccs_period, x
	sta	nsm_tempperiod
	
	lda	nsm_r1
	adc	nsm_channels+ccs_period+1, x
	
	
	; check overflow
	bcc	+
	lda	#255
	sta	nsm_channels+ccs_period, x
	sta	nsm_tempperiod
+
	sta	nsm_channels+ccs_period+1, x
	sta	nsm_tempperiod+1

	lda	nsm_cflags
	ora	#cflag_pitch
	sta	nsm_cflags
	rts
	
;-----------------------------------------------------------------------------------
NS3M_CH_PSD:			; 48 cycles
;-----------------------------------------------------------------------------------

; channel period slide down, 16bit
; a = amount.LO
; r1= amount.HI
; x = c offset

	sta	nsm_r2
	lda	nsm_channels+ccs_period, x
	sec
	sbc	nsm_r2
	sta	nsm_channels+ccs_period, x
	sta	nsm_tempperiod
	
	lda	nsm_channels+ccs_period+1, x
	sbc	nsm_r1
	
	bcs	+
	lda	#0
	sta	nsm_channels+ccs_period, x
	sta	nsm_tempperiod
+
	sta	nsm_channels+ccs_period+1, x
	sta	nsm_tempperiod+1
	lda	nsm_cflags
	ora	#cflag_pitch
	sta	nsm_cflags
	rts

;-----------------------------------------------------------------------------------
NS3M_GETVTABLE:					; 62 cycles
;-----------------------------------------------------------------------------------

	; a = depth
	; r1= value
	; returns
	; a = depth*table
	; sine implemented...
	sec			; decrement a (sine table starts at 1)
	sbc	#1
	bcs	+		; check overflow
	adc	#1		; cancel overflow
+
	asl			; depth *16
	asl			;
	asl			;
	asl			;
	sta	nsm_r2		; save result
	lda	nsm_r1		; load index
	and	#31		; mask
	cmp	#16		; check if > 16 (other sine half)
	bcc	++		; if not skip this section
	
	and	#15		; if so get 15-(value&15)
	eor	#15		; 
	clc
++
	adc	nsm_r2		; (carry cleared), add depth value
	
	tay			; trasnfer to index
	lda	NS3M_SINE, y	; load sine value
	tay			; save
	lda	nsm_r1		; check if in the negative zone
	and	#32		; ...
	
	beq	+		; if not, skip
	tya			; get sine value
	eor	#255		; negate
;	clc			; (carry cleared still)
	adc	#0
	rts			; return
+
	tya			; get sine value
	
	rts			; return

;======================================================================================
;=                                   APU CONTROL
;======================================================================================

note2dpcm:
.db	$00,$11,$32,$43,$54,$65,$77,$88,$98,$A9,$BA,$BB,$CC,$CC,$DD,$ED,$EE,$EE

;------------------------------------------------------------------------------------
NS3M_NOTE2DPCM:
;------------------------------------------------------------------------------------

;	F  c 84
;	E  g 79
;	D  e 76
;	C  c 72
;	B  a 69
;	A  g 67
;	9  f 65
;	8  d 62 
;	7  c 60
;	6  b 59
;	5  a 57
;	4  g 55
;	3  f 53
;	2  e 52
;	1  d 50
;	0  c 48

	lda	nsm_channels+ccs_note, x
	clc
	adc	#12
	sec
	sbc	#48
	bcc	_n2dpcm_less
	cmp	#36
	bcs	_n2dpcm_more
	lsr
	tay
	lda	note2dpcm, y
	bcs	+
	and	#$0F
	rts

+	lsr
	lsr
	lsr
	lsr
	rts

_n2dpcm_less:		; < 48
	lda	#0
	rts

_n2dpcm_more:		; >= 84
	lda	#$F
	rts

;----------------------------------------------------------------
NS3M_PERIOD2NOISE:
;----------------------------------------------------------------

	; ILL JUST LEAVE THIS ONE ALONE.....

	; binary search for amiga period->nes noise period
	; a = period
	; r1 = period HI
	
	lsr nsm_r1		; get amiga period
	ror a
	lsr nsm_r1
	ror a
	lsr nsm_r1		; and shift one more? :)
	ror a
	
	;0,1,2,4,  8,12,16,20,    25,31,47,63,  95,127,254,508,
	;0 1 2 3   4 5  6  7      8  9  10 11   12 13  14  15
	lsr nsm_r1		; >> 3
	ror a			;
	lsr nsm_r1		;
	ror a			;
	lsr nsm_r1		;
	beq +			; if > 255 then answer = 15
	lda #15			;
	rts
+
	ror a
	cmp #25
	bcs +
	cmp #8
	bcs ++
	cmp #2
	bcs +++
	rts			;0/1
+++
	cmp #4
	bcs ++++
	rts			; 2
++++
	lda #3
	rts
++
	cmp #16
	bcs ++
	cmp #12
	bcs +++
	lda #4
	rts
+++
	lda #5
	rts
++
	cmp #20
	bcs +++
	lda #6
	rts
+++
	lda #7
	rts
+
	cmp #95
	bcs +
	cmp #47
	bcs ++
	cmp #31
	bcs +++
	lda #8
	rts
+++
	lda #9
	rts
++
	cmp #63
	bcs ++
	lda #10
	rts
++
	lda #11
	rts
+
	cmp #254
	bcs +
	cmp #127
	bcc ++
	lda #13
	rts
++
	lda #12
	rts
+
	lda #14
	rts

;--------------------------------------------------------------------------------------
NS3M_FASTFORWARD:			; (rows * 213) cycles, worst case :)
;--------------------------------------------------------------------------------------

; r1 = rows

	ldy #0					; reset pointer			2

nff_loop:	
	lda (nsm_pattread), y			; read byte			; { 187 cycles
	bne	+				; check zero?
	iny					; increment pointer
	jmp	++				; row complete

+						; if not:
	iny					; increase pointer
	asl					; shift param&effect bit out
	bcc	+				; set?
	iny		; PARAM			; skip param
	iny		; EFFECT		; skip effect
+
	asl					; shift volume bit out
	bcc	+				; set?
	iny		; VOLUME		; skip volume
+
	asl					; shift note&inst bit out
	bcc	+				; set?
	iny		; INST			; skip inst
	iny		; NOTE			; skip note
+
	jmp	nff_loop			; loop				; }
++						; row complete:
	clc					;				; { 26 cycles
	tya					; load akku with index
	adc	nsm_pattread			; add to pattern offset
	sta	nsm_pattread
	lda	nsm_pattread+1
	adc	#0
	sta	nsm_pattread+1
	dec	nsm_r1				; decrement counter
	bne	NS3M_FASTFORWARD		; loop				; }

	rts					; return

_nmcua_jt1:
	.dw	NS3M_APU_PULSE1
	.dw	NS3M_APU_PULSE2
	.dw	NS3M_APU_TRIANGLE
	.dw	NS3M_APU_NOISE
	.dw	NS3M_APU_DPCM
	.dw	NS3M_VRC6_PULSE1
	.dw	NS3M_VRC6_PULSE2
	.dw	NS3M_VRC6_SAWTOOTH
	
;----------------------------------------------------------------------------------
NS3M_CH_UPDATEAPU:
;----------------------------------------------------------------------------------

	lda	#8
	bit	nsm_cflags
	bne	+

	lda	nsm_channels+ccs_apuctrl, x
	tay
	lda	_nmcua_jt1, y
	sta	nsm_r1
	lda	_nmcua_jt1+1, y
	sta	nsm_r2

	jmp	(nsm_r1)
+	rts

;-------------------------------------------------------------------
NS3M_APU_PULSE2:
;-------------------------------------------------------------------

	ldy	#4

;-------------------------------------------------------------------
NS3M_APU_PULSE1:
;-------------------------------------------------------------------

	; y is 0 or 4

	lda	nsm_channels+ccs_inst,x
	sec
	sbc	#1
	and	#3
	ror
	ror
	ror
	ora	#%00110000
	sta	nsm_r1

	jsr	ns3m_clampvol
	
	ora	nsm_r1
	sta.w	$4000,y
	
	lda	#1
	bit	nsm_cflags
	beq	++
	
	lda	nsm_tempperiod+1
	lsr
	ror	nsm_tempperiod
	lsr
	ror	nsm_tempperiod

	cmp	#%1000
	bcc	+

	lda	#255
	sta	nsm_tempperiod
+

	ora	#%11111000
	
	cmp	nsm_apucopyp+3,y
	beq	+
	sta	nsm_apucopyp+3,y
	sta.w	$4003,y
	
+
	lda	nsm_tempperiod
	cmp	nsm_apucopyp+2,y
	beq	++
	sta.w	$4002,y
	sta.w	nsm_apucopyp+2,y
++	
	
	rts

;-----------------------------------------------------------------
NS3M_APU_TRIANGLE:
;-----------------------------------------------------------------

	lda	nsm_tempvol
	bne	+
	lda	#128
	sta.w	$4008
	lda	#0
	sta.w	$400A
	sta.w	$400b
	rts
+
	
	lda	nsm_tempperiod
	lsr	nsm_tempperiod+1
	ror
	lsr	nsm_tempperiod+1
	ror
	lsr	nsm_tempperiod+1		; is that right?
	ror							;
	
	; max period = 2047
	
	pha							; clamp period
	lda	nsm_tempperiod+1
	cmp	#8
	bcc	++
	lda	#7
	sta	nsm_tempperiod+1
	pla
	lda	#255
	jmp	+++
++
	pla
+++
	

	sta.w	$400A
	lda	nsm_tempperiod+1
	ora	#%11111000
	sta.w	$400B
+
	lda	#127
	sta.w	$4008
	
	rts

;-----------------------------------------------------------------
NS3M_APU_NOISE:
;-----------------------------------------------------------------

	jsr	ns3m_clampvol
	ora	#%110000
	sta	$400C	

	lda	#1
	bit	nsm_cflags
	beq	+
	
	lda	#0
	sta	nsm_r2
	
	lda	nsm_channels+48+ccs_inst
	cmp	#6
	beq	+
	lda	#$80
	sta	nsm_r2
+
	
	lda	nsm_tempperiod+1
	sta	nsm_r1
	lda	nsm_tempperiod
	jsr	NS3M_PERIOD2NOISE

	ora	nsm_r2
	
	sta	$400E
	
	lda	#%0
	sta	$400F
+
	rts

;-----------------------------------------------------------------
NS3M_APU_DPCM:
;-----------------------------------------------------------------

	lda	nsm_channels+ccs_vol, x
	cmp	#0
	bne	+
	lda	#%1111
	sta.w	$4015
	rts
+

	lda	#2
	bit	nsm_cflags
	beq	+
	lda	#%1111
	sta.w	$4015
	lda	#32
	sta	$4011
+
	lda	#1
	bit	nsm_cflags
	beq	+
	
	jsr	NS3M_NOTE2DPCM
	sta	nsm_r1
	; get loop flag
	lda	nsm_channels+ccs_inst+64

	sec
	sbc	#8
	pha
	lsr
	lsr
	lsr
	clc
	adc	#nsf_sdLOOP
	tay
	lda	(nsm_sdad), y
	sta	nsm_r2
	pla
	and	#7
	tay
	lda	NS3M_BITS, y
	and	nsm_r2
	beq	++
	lda	#$40
++	
	ora	nsm_r1
	sta	$4010
+
	
	lda	#2
	bit	nsm_cflags
	beq	+
	lda	nsm_channels+ccs_inst+64
	cmp	#8
	bcc	+
	sbc	#8
	tay
	lda	(nsm_sdDPCMB), y

	sta	$5FFC
	adc	#0			; ( carry set, +1 )
	sta	$5FFD
	lda	(nsm_sdDPCMO), y
	sta	$4012
	lda	(nsm_sdDPCML), y
	beq	+
	sta	$4013
	
	lda	#%11111
	sta.w	$4015
+
	
	rts

;-----------------------------------------------------------------
NS3M_VRC6_PULSE1:
;-----------------------------------------------------------------

	lda	nsm_channels+ccs_inst,x
	sec
	sbc	#8
	and	#7
	asl
	asl
	asl
	asl
	sta	nsm_r1
	jsr	ns3m_clampvol
	ora	nsm_r1
	sta.w	$9000
	
	lda	#1
	bit	nsm_cflags
	beq	++
	
	lda	nsm_tempperiod+1
	lsr
	ror	nsm_tempperiod
	lsr
	ror	nsm_tempperiod

	cmp	#%1000
	bcc	+

	lda	#255
	sta	nsm_tempperiod
+
	ora	#%10000000
	
	cmp	nsm_vrc6copy+2,y
	beq	+
	sta	nsm_vrc6copy+2,y
	sta.w	$9002
	
+
	lda	nsm_tempperiod
	cmp	nsm_vrc6copy+1,y
	beq	++
	sta.w	$9001
	sta.w	nsm_vrc6copy+1,y
++	
	
	rts

;-----------------------------------------------------------------
NS3M_VRC6_PULSE2:
;-----------------------------------------------------------------

	lda	nsm_channels+ccs_inst,x
	sec
	sbc	#8
	and	#7
	asl
	asl
	asl
	asl
	sta	nsm_r1
	jsr	ns3m_clampvol
	ora	nsm_r1
	sta.w	$A000
	
	lda	#1
	bit	nsm_cflags
	beq	++
	
	lda	nsm_tempperiod+1
	lsr
	ror	nsm_tempperiod
	lsr
	ror	nsm_tempperiod

	cmp	#%10000
	bcc	+

	lda	#255
	sta	nsm_tempperiod
+
	ora	#%10000000
	
	cmp	nsm_vrc6copy+5,y
	beq	+
	sta	nsm_vrc6copy+5,y
	sta.w	$A002
	
+
	lda	nsm_tempperiod
	cmp	nsm_vrc6copy+4,y
	beq	++
	sta.w	$A001
	sta.w	nsm_vrc6copy+4,y
++	
	
	rts

sawtooth_vtable:	; conversion 0->32 : 0->42
.db	0 , 1, 3, 4, 5, 7, 8, 9,10,12,13,14,16,17,18,20,
.db	21,22,24,25,26,28,29,30,32,33,34,35,37,38,39,41,42
	
;-----------------------------------------------------------------
NS3M_VRC6_SAWTOOTH:
;-----------------------------------------------------------------
	lda	nsm_tempvol
	lsr

	tay
	lda.w	sawtooth_vtable, y
	sta	$B000	; saw accum rate
	
	lda	#1
	bit	nsm_cflags
	beq	++
	
	lda	nsm_tempperiod+1
	lsr
	ror	nsm_tempperiod
	lsr
	ror	nsm_tempperiod

	cmp	#%10000
	bcc	+

	lda	#255
	sta	nsm_tempperiod
+
	ora	#%10000000
	
;	cmp	nsm_vrc6copy+7,y
;	beq	+
	sta	nsm_vrc6copy+7,y
	sta.w	$B002
	
;+
	lda	nsm_tempperiod
;	cmp	nsm_vrc6copy+6,y
;	beq	++
	sta.w	$B001
	sta.w	nsm_vrc6copy+6,y
;++	
	
	rts

ns3m_clampvol:
	lda	nsm_tempvol
	beq	++
	cmp	#64
	bcc	+
	lda	#63
+	cmp	#4
	bcs	+
	lda	#4
+	lsr
	lsr
++	rts
	
.ENDS
