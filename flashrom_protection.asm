;#www.piotrbania.com/all/ti89/flashrom_protection.asm#
;
;
;
;	Writting to the FlashROM Memory on Texas Instruments Calculators
;	----------------------------------------------------------------
;	by Piotr Bania <bania.piotr@gmail.com>
;	http://www.piotrbania.com
;
;
;	Tested on:	Ti-89 Titanium HW3 AMS 3.10
;
;
;
; 	0.   DISCLAIMER
;       
;
;	Author takes no responsibility for any actions with provided informations or 
;	codes. The copyright for any material created by the author is reserved. Any 
;	duplication of codes or texts provided here in electronic or printed 
;	publications is not permitted without the author's agreement. 
;
;
;	1. ABOUT THIS FILE
;
;	This is a Proof of concept code, which shows one of the possible ways for
;	writting to FLASH ROM on ti calc (tested on ti89 titanium with AMS 3.10 HW3)
;	This is one of the way to "turn off" the Flash write protection.
;	
;	Couple of things that reside in Flash ROM:
;	(0x200000-0x20FFFF)				- 	Boot sector
;	(0x210000-0x211FFF)				-	Certificate Memory
;	(0x212000-0x21FFFF)				-	System privileged
;	(0x220000-(Border can vary))			- 	Operating System (AMS)
;	(Border can vary)-0x3FFFFF))			- 	Archive Memory
;
;
;	IMPORTANT NOTE:
;
;	By modifing your Flash ROM you may make your calculator permanently 
;	unbootable. So play with this code for your own responsibility.
;
;
;	HOW TO WRITE TO THE FLASHROM AKA YOUR WRITTING ROUTINE
;      	
;	The Flash ROM seems to be an Epson device (LH28F160S3T or LH28F320 according 
;	to the amount of memory). Writing to the ROM requires special writing control
;	codes. Some of the things are neatly explained by Johan Borg, here: 
;	http://tict.ticalc.org/docs/flashrom.txt. 
;
;	Here are some main subset of operations that can be used:
;	0x1010		- Write setup (next word will be written)
;	0x2020		- Erase setup
;	0x5050		- Clear status register
;	0x9090		- Read ID codes
;	0xD0D0		- Erase confirm
;	0xFFFF		- Read memory (or reset)
;
;	Little sample, erasing 64b bit block starting from MY_ADDR:
;
;       --------------------------------------------------------
;	move.l		#MY_ADDR,a0
;	move.w 		#$5050,(a0) 	; Clear Status Register
;	move.w 		#$2020,(a0) 	; Erase Setup
;	move.w 		#$D0D0,(a0) 	; Erase Confirm
;
;	write_state_busy:
;	move.w 		(a0),d0 	; Read Status Register
;	btst 		#7,d0 		; 1 = Ready
;	beq 		write_state_busy
;	move.w 		#$FFFF,(a0) 	; Read mem
;       --------------------------------------------------------
;
;
;
;	that's all, have fun!






	xdef	_ti89
	xdef	_main
	xdef	_nostub
	include "os.h"




aAddressError	equ	$0C			; address error (vector address)

	

_main:	
	movem.l	a0-a6/d0-d7,-(a7)	; pushad
	move.l  $C8,a4			; a4 = ROMCALL jump table

	move.l	a4,d0
	and.l	#$E00000,d0		; d0 = now ROMBASE (ti89 hw3 ams3.01: 800000h)
	move.l	d0,a3


	; ------------------------------------------------------------
	; now we are searching for this sequence of bytes
	; instruction at 0x81225e will flow the execution to the 
	; Address Mode error
	; ------------------------------------------------------------
	; ROM:0081225a                 move    #$2700,sr
	; ROM:0081225e                 move.w  d0,(a0)      <-- ACCESS VIOLATION SHOULD OCCUR HERE
	; ROM:00812260                 nop
	; ROM:00812262                 nop
	; ROM:00812264                 nop
	; ------------------------------------------------------------
	
scan_bytes:
	add.l	#2,a3
	cmpi.l	#$46fc2700,(a3)
	bne.s	scan_bytes		; scan, scan


	; for this point we have a potencial code location, however there are a lot of
	; move #$2700,sr instructions up there, so we need to setup some nop filter
	; to make sure it is the thing we want
	
	cmpi.l	#$4E714E71,$6(a3)
	bne.s	scan_bytes

	trap    #$C			; i'm super cookie!!! (to avoid priv-violation barfs)
					; supervisior mode	
	adda.l  #$1C0000,sp		

					; a3 = needed address
	move.l	aAddressError,d3	; d3 = old AddressError addr
	lea	hook_AddressError,a0
	bclr.b	#2,$600001		; modify the write protect vector table bits
	move.l	a0,aAddressError	; modify the Address Error handler
	bset	#2,$600001		; reset

	move.l	#$DEADBEEF,a0		; this will cause an AddressError exception at 81225eh 
	jmp	(a3)

hook_AddressError:
	lea     ($4C00).w,a7		; stack flow to LCD area

	illegal	

;	<--- YOUR EEPROM WRITING ROUTINE HERE AND WHATEVER BLA BLA --->



		