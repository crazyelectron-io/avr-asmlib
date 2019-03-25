
/*==================================================================================================*;
;*SYNOPSIS:																							*;
;*	Interrupt driven buffered EEPROM reading and writing library routines for 8-bit AVR MCUs.		*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	20141130 v0.2	Removed SFR_OFFSET fix.															*;
;*	20141031 v0.1	Initial test version.															*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Routines for reading, writing and erasing the EEPROM memory in 8-bit AVR MCUs.					*;
;*																									*;
;*NOTES:																							*;
;*	1. It is assumed that all generic initialization, like stackpointer setup is done by the		*;
;*		calling program.																			*;
;*	2.	Don't use 1st byte of EEPROM as it may get corrupted during power down.						*;
;*	3.	Writing or Erasing takes about 1.8ms on an ATtiny (Erase+Write 3.6ms).						*;
;*																									*;
;*COPYRIGHT:																						*;
;*	(c)2014 by Ron Moerman, All Rights Reserved.													*;
;*																									*;
;*	This program comes with ABSOLUTELY NO WARRANTY.													*;
;*	This is free software, and you are welcome to redistribute it under certain conditions.			*;
;*	The program and its source code are published under the GNU General Public License (GPL).		*;
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.										*;
;*																									*;
;*	$File: eeprom.S $																				*;
;*	$Revision: 0.2 $																				*;
;*	$ASM: AVR-GCC AS $																				*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Sunday, November 30, 2014 21:03:36 UTC $													*;
;*==================================================================================================*/

#define ___EEPROM_LIB___

/*==================================================================================================*;
;*                                   I N C L U D E   H E A D E R S                                  *;
;*==================================================================================================*/

//#define __SFR_OFFSET 0
		.nolist
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr_macros.h>
		.list
#include <eeprom.h>


/*==================================================================================================*;
;*                          D E V I C E   D E P E N D E N T   D E F I N E S                         *;
;*==================================================================================================*/

#if defined(__AVR_ATtiny2313__)||defined(__AVR_ATtiny2313A__)||defined(__AVR_ATtiny4313__)
 // Something....
#else
 #error "Only ATtiny2313/ATtiny2313A/ATtiny4313 supported (for now)"
#endif


/*==================================================================================================*;
;*                                         C O N S T A N T S                                        *;
;*==================================================================================================*/

#define EEPROM_IGNORE_SELFPROG		1					//Remove SPM flag polling from code if !0.
#define BUFFER_SIZE		8								//Buffer for 8 bytes to write.
#if (EEPROMEND > 256)
 #define ADDRESS_SIZE	(2*BUFFER_SIZE)
#else
 #define ADDRESS_SIZE	BUFFER_SIZE
#endif


/*==================================================================================================*;
;*                                L I N K E R   D E F I N I T I O N S                               *;
;*==================================================================================================*/

//--- Interrupt service routine(s).
		.global EEPROM_Ready_vect						;EEPROM Ready interrupt routine entrypoint.


/*==================================================================================================*;
;*                                   E E P R O M   V A R I A B L E S                                *;
;*==================================================================================================*/

		.section .eeprom
// Tell the linker to start your own EEPROM data at 0x01, first byte of EEPROM could get corrupted.


/*==================================================================================================*;
;*                           L I B R A R Y   L O C A L   V A R I A B L E S                          *;
;*==================================================================================================*/
		.section .data

// We put the data to write to EEPROM in a buffer.
bcount:	.byte	0										;EEPROM buffer location in use.
abuf:	.space	ADDRESS_SIZE							;Store EEPROM address bytes in this buffer.
														;  0xFF(FF) means empty slot.
dbuf:	.space	BUFFER_SIZE								;Store EEPROM data bytes in this buffer.
// Note: Data buffer must be right after address buffer (byte aligned).
initflag:
		.byte	0										;EEPROM routines initialized flag.


/*==================================================================================================*;
;*                                I N T E R R U P T   R O U T I N E S                               *;
;*==================================================================================================*/
		.section .text

/*--------------------------------------------------------------------------------------------------*;
;* EEPROM_Ready_vect: ISR triggered on EEPROM ready.												*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	ISR triggered on EEPROM ready for write.														*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	None.																							*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R0 (to save status register).																	*;
;*																									*;
;*MAX STACK USAGE:																					*;
;*	9 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1.	This ISR consumes xxx-xxx MCU cycles, including reacting to the EEPROM interrupt and		*;
;*		returning to the running code.																*;
;*--------------------------------------------------------------------------------------------------*/
EEPROM_Ready_vect:
		in		R0,IO_ADDR(SREG)						;Save SREG status. (1)
; Check if self porgramming is currently active.
#if (!EEPROM_IGNORE_SELFPROG)
		sbic	IO_ADDR(SPMCSR),SPMEN					;Check if a SPM command is running.
		rjmp	_ee_rdy_exit							;Return if so. (2)
#endif
		PUSHM	R16,R17,R24,XL,YL						;Save used register. (10/14)
#if (RAMEND > 256)
		push		YH
#endif
#if (EEPROMEND>256)
		push	XH
#endif
; Get EEPROM memory location to program from the EEPROM Address Buffer.
		ldi		YL,lo8(abuf)							;Y points at EEPROM address buffer. (2)
#if (RAMEND > 256)
		ldi		YH,hi8(abuf)
#endif
		lds		R24,bcount								;Get buffer index counter. (3)
		dec		R24
		sts		bcount,R24								;Store updated buffer counter. (2)
		add		YL,R24									;Point at current head of buffer. (1/2)
#if (EEPROMEND > 256)
		adc		YH,ZEROR
#endif
		ld		R24,Y									;Get EEPROM address to program.
		out		IO_ADDR(EEAR),R24						;Place EEPROM address in EEAR Register. (1)
#if (EEPROMEND > 256)
		ldd		R24,Y+1
		out		IO_ADDR(EEARH),R24
#endif
; Write data byte from buffer to EEPROM, while checking which bits are changed.
		ldd		R24,Y+ADDRESS_SIZE						;Read data byte from EEPROM Data Buffer.
; First, read old EEPROM data and write new byte tot EEPROM Data Register.
		sbi		IO_ADDR(EECR),EERE						;Start EEPROM Read operation.
		in		R16,IO_ADDR(EEDR)						;Get old EEPROM value from EEPROM Data Register.
		out		IO_ADDR(EEDR),R24						;Write new EEPROM value to EEPROM Data Register. (1)
; Check if any bits changed to '1' in the new value.
		eor		R16,R24									;Get bit difference between old and new value. (1)
		mov		R17,R16									;Save difference for later use. (2)
		and		R16,R24									;Check for extra '1's in new value. (1)
		breq	_ee_rdy_no_ones							;  If not, skip. (1/2)
; Some bits need to be erased to '1'.
; Check if any bits in the new value are '0', otherwise just erase.
		cpi		R24,0xFF
		breq	_ee_rdy_no_zeros
; Some bits need to be programmed to '0'; have to do Erase+Write.
		ldi		R16,(1<<EEMPE)|(0<<EEPM1)|(0<<EEPM0)	;Set Master Program Enable bit and, (1)
		out		IO_ADDR(EECR),R16						;  Erase+Write mode. (1)
		rjmp	_ee_rdy_write							;Go start Erase+Write operation. (2)
; Now we know that all bits should be erased to 0xFF; do just Erase.
_ee_rdy_no_zeros:
		ldi		R16,(1<<EEMPE)|(0<<EEPM1)|(1<<EEPM0)	;Set Master Program Enable and, (1)
		out		IO_ADDR(EECR),R16						;  Erase-only mode. (1)
		rjmp	_ee_rdy_write							;Start Erase-only operation. (2)
; No bits need to be erased to '1'.
; Check if any bits are changed from '1' in the old value.
_ee_rdy_no_ones:
		tst		R17										;Any bits changed from '1' in the old value? (1)
		breq	_ee_rdy_done							; If not, we're done. (1/2)
; Now we know that some bits need to be programmed to '0'.
		out		IO_ADDR(EEDR),R24						;Set EEPROM data register. (1)
		ldi		R16,(1<<EEMPE)|(1<<EEPM1)|(0<<EEPM0)	;Set Master Program Enable and,
		out		IO_ADDR(EECR),R16						;  Write-only mode.
_ee_rdy_write:
		sbi		IO_ADDR(EECR),EEPE						;Start Write-only operation.
; Reset EEPROM Address Buffer location.
_ee_rdy_done:
		ser		R24
		st		Y,R24									;Write 0xFF(FF) to Address Buffer location.
#if (EEPROMEND > 256)
		std		Y+1,R24
#endif
;		std		Y+ADDRESS_SIZE,R24						;Write 0xFF to Data Buffer location.
		sbi		IO_ADDR(EECR),EERIE						;Enable EE_RDY interrupt.
; Check if EEPROM buffer is empty.
		lds		R24,bcount
		tst		R24
		brne	_ee_rdy_exit							;SKip if not empty.
; Buffer empty, disable EEPROM interrupts.
		cbi		IO_ADDR(EECR),EERIE						;Disable EE_RDY Interrupt.
; Restore and return.
_ee_rdy_exit:
#if (EEPROMEND > 256)
		pop		XH										;Restore used register (12/14).
#endif
#if (RAMEND > 256)
		pop		YH
#endif
		POPM	R16,R17,R24,XL,YL
		out		IO_ADDR(SREG),R0						;Restore SREG and return from interrupt.
		reti


/*==================================================================================================*;
;*                                 L I B R A R Y   R O U T I N E S									*;
;*==================================================================================================*/

/*--------------------------------------------------------------------------------------------------*;
;* _ee_init: Initialize the EEPROM Address and Data Buffer with 0xFF.								*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	This function writes 0xFF in all EEPROM Address and Data buffer locations to indicate empty		*;
;*	slots. Set the initflag to indicate it is initialized.											*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	None.																							*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	YL (YH if SRAM>256 bytes).																		*;
;*																									*;
;*LOCAL STACK USAGE:																				*;
;*	? bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes XX MCU cycles, including returning to the calling program.			*;
;*--------------------------------------------------------------------------------------------------*/
		.func	_ee_init
_ee_init:
		push	R24										;Save working register. (2)
		ldi		YL,lo8(abuf)							;Get address of EEPROM Address Buffer. (1/2)
#if (RAMEND > 256)
		ldi		YH,hi8(abuf)
#endif
		ser		R24										;Will write 0xFF in the EEPROM Address Buffer. (1)
		ldi		R16,ADDRESS_SIZE						;Get size of EEPROM Address Buffer. (1)
_ini_loop:
		st		Y+,R24									;Flush EEPROM Address Buffer location.
		dec		R16										;Count down. (1)
		brne	_ini_loop								;Loop while not done. (1/2)
		sts		initflag,R24							;Set init flag. (2)
		pop		R24										;Restore used register. (2)
		ret												;Return. (4)
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
;* ee_readbyte: Read a byte from EEPROM at the specified EEPROM location.							*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	This function reads one byte from EEPROM at the specified EEPROM location. First we check if	*;
;*	the data is still in the buffer, otherwise we read from EEPROM.									*;
;*																									*;
;*INPUT:																							*;
;*	X(L) = EEPROM address to read.																	*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = data byte read from EEPROM location.														*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R24.																							*;
;*																									*;
;*LOCAL STACK USAGE:																				*;
;*	6 bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes XX cpu cycles, including returning to the calling program.			*;
;*	2.	The MCU is halted for 4 clock cycles during EEPROM read.									*;
;*--------------------------------------------------------------------------------------------------*/
		.func	ee_readbyte
ee_readbyte:
		PUSHM	R16,YL									;Save used registers. (4/6)
#if (RAMEND >256)
		push	YH
#endif
; Is the EEPROM Address Buffer already initialized?
		lds		R16,initflag							;Get init flag in R16. (2)
		sbrs	R16,1									;Skip if the init flag is already set. (1/2)
		rcall	_ee_init								;Otherwise do one-time initialization.
; Search the EEPROM buffer for the byte we want to read.
		ldi		YL,lo8(abuf)							;Y points at EERPOM address buffer. (2)
#if (RAMEND >256)
		ldi		YH,hi8(abuf)
#endif
		cli												;No interrupts during buffer access. (4)
_ee_rd_loop:
		ld		R16,Y									;Compare addresses. (3)
		cp		R16,XL
		brne	_ee_rd_next								;Skip if no match. (1/2)
#if (EEPROMEND > 256)
		ldd		R16,Y+1
		cp		R16,XH
		brne	_ee_rd_next
#endif
; Address is in buffer, return corresponding data byte.
		adiw	YL,ADDRESS_SIZE							;Point Y at data buffer.
		ld		R24,Y
		rjmp	_ee_rd_exit
; Update index and loop.
_ee_rd_next:
#if (RAMEND > 256)
		adiw	YL,2									;Update EEPROM Address Buffer pointer.
#else
		inc		YL
#endif
		cpi		YL,lo8(dbuf)							;End of buffer reached?
		brne	_ee_rd_loop
#if (RAMEND > 256)
		cpi		YH,hi8(dbuf)
		brne	_ee_rd_loop
#endif
; Not in the buffer, so read directly from EEPROM.
		in		R16,IO_ADDR(EECR)						;Backup EERIE bit (in R16).
		cbi		IO_ADDR(EECR),EERIE						;Disable EEPROM interrupt to let the EEPROM read in.
_ee_rd_wait:
		sbic	IO_ADDR(EECR),EEPE						;Check if EEPROM currently being accessed.
		rjmp	_ee_rd_wait								;  If so, wait.
		out		IO_ADDR(EEAR),XL						;Place address in EEPROM Address Register.
#if (EEPROMEND > 256)
		out		IO_ADDR(EEARH),XH
#endif
		sbi		IO_ADDR(EECR),EERE						;Assert EEPROM Read Enable.
		in		R24,IO_ADDR(EEDR)						;Read the data from the EEPROM Data Register.
; Clear EEPROM addres to prevent corruption.
		out		IO_ADDR(EEAR),ZEROR						;Also use BOD to prevent corruption from low VCC. (1/2)
#if (EEPROMEND > 256)
		out		IO_ADDR(EEARH),ZEROR
#endif
		sbrc	R16,EERIE
		sbi		IO_ADDR(EECR),EERIE						;Restore EERIE (EE_RDY Interrupt Enable) bit.
; Return the requested byte.
_ee_rd_exit:
		sei												;Enable interrupts to allow EE_RDY interrupt(s).
#if (RAMEND > 256)
		pop		YH										;Restore used registers and return.
#endif
		POPM	R16,YL
		ret
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
;* ee_writebyte: Write a byte to EEPROM at the specified memory location.							*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	This function writes one byte to EEPROM from the specified memory location. The difference		*;
;*	between existing byte and the new value is used to select the most efficient EEPROM				*;
;*	programming mode.																				*;
;*	Programming the byte is controlled by the EE_RDY interrupt routine, so we won't wait until the	*;
;*	EEPROM is ready to write the byte, but return immediately if buffer not full.					*;
;*																									*;
;*INPUT:																							*;
;*	X(L) = EEPROM address to write.																	*;
;*	R24 = Byte to write in EEPROM.																	*;
;*																									*;
;*OUTPUT:																							*;
;*	None.																							*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	None.																							*;
;*																									*;
;*LOCAL STACK USAGE:																				*;
;*	7-8 bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes XX cpu cycles, including returning to the calling program.			*;
;*--------------------------------------------------------------------------------------------------*/
		.func	ee_writebyte
ee_writebyte:
		PUSHM	R16,YL									;Save used registers. (4/6)
#if (RAMEND > 256)
		push	YH
#endif
; Is the EEPROM Address Buffer already initialized?
		lds		R16,initflag							;Get init flag in R16. (2)
		sbrs	R16,0x01								;Skip if the init flag is already set. (1/2)
		rcall	_ee_init								;Otherwise do one-time initialization.
; Search the EEPROM buffer for the address we want to write to.
		ldi		YL,lo8(abuf)							;Y points at EERPOM Address Buffer. (1/2)
#if (RAMEND > 256)
		ldi		YH,hi8(abuf)
#endif
		cli												;No interrupts during buffer access. (1)
_ee_wrt_loop:
		ld		R16,Y									;Compare EEPROM addresses. (3)
		cp		R16,XL
		brne	_ee_wrt_next							;Skip if no match. (1/2)
#if (EEPROMEND > 256)
		ldd		R16,Y+1
		cp		R16,XH
		brne	_ee_wrt_next
#endif
; EEPROM address is already in buffer, update data byte and return.
		adiw	YL,ADDRESS_SIZE							;Point Y at data buffer.
		st		Y,R24									;Store new data byte.
		rjmp	_ee_wrt_exit
; Update index and loop through buffer.
_ee_wrt_next:
#if (EEPROMEND > 256)
		adiw	YL,2									;Update double byte EEPROM Address Buffer pointer. (2)
#else
		inc		YL										;Update single byte EEPROM Address Buffer pointer. (1)
#endif
		cpi		YL,lo8(dbuf)							;End of EEPROM Address Buffer reached? (1)
		brne	_ee_wrt_loop							;Loop if not. (1/2)
#if (RAMEND > 256)
		cpi		YH,hi8(dbuf)
		brne	_ee_wrt_loop
#endif
; EEPROM address is not in the buffer, so add data and address to EEPROM Buffer.
		sei												;Enable interrupts. (1)
; Wait while buffer is full.
1:		lds		R16,bcount								;Get buffer size counter.
		cpi		R16,BUFFER_SIZE							;Is the buffer full? (1)
		brsh	1b										;  Yes, loop. (1/2)
; Put address and data in EEPROM Buffer.
		cli												;No imterrupts during buffer update. (1)
		ldi		YL,lo8(abuf)							;Y points at EERPOM Address Buffer. (1/2)
#if (RAMEND >256)
		ldi		YH,hi8(abuf)
#endif
		lds		R16,bcount								;Reread buffer counter. (2)
		add		YL,R16									;Update to current position. (1/2)
#if (EEPROMEND > 256)
		adc		YH,ZEROR
#endif
		st		Y,XL									;Store address in buffer. (2/4)
#if (EEPROMEND > 256)
		st		Y+1,XH
#endif
		adiw	YL,ADDRESS_SIZE							;Point at corresponding EEPROM Data Buffer location.
		st		Y,R24									;Store data in EEPROM Data Buffer.
		inc		R16										;Update buffer counter.
		sts		bcount,R16
; Enable the EEPROM ready interrupt.
		sbi		IO_ADDR(EECR),EERIE						;Set Enable EE_RDY interrupt bit.
_ee_wrt_exit:
		sei												;Enable interrupts to allow EE_RDY interrupt. (1)
#if (RAMEND > 256)
		pop	YH
#endif
		POPM	R16,YL									;Restore and return. (8/10)
		ret
		.endfunc

		.end
