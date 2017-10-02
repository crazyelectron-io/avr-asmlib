/*==================================================================================================*;
;*SYNOPSIS:																							*;
;*	Error buffering library functions to store and retrieve multiple error codes (LIFO).			*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	0.2 changed to assembler and library module.													*;
;*	0.1	Initial test version.																		*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Routines for error buffer writing and reading to store and retrieve multiple errors that		*;
;*	occur during data processing (like UART send/receive).											*;
;*	The error buffer holds up to MAX_ERR_ENTRIES of error codes.									*;
;*																									*;
;*NOTES:																							*;
;*	Register 6 is used exclusively by the error buffer routines and should not be used elsewhere.	*;
;*																									*;
;*COPYRIGHT:																						*;
;*	(c)2014 by Ron Moerman, All Rights Reserved.													*;
;*																									*;
;*	This program comes with ABSOLUTELY NO WARRANTY.													*;
;*	This is free software, and you are welcome to redistribute it under certain conditions.			*;
;*	The program and its source code are published under the GNU General Public License (GPL).		*;
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.										*;
;*																									*;
;*	$File: errorbuf.S $																				*;
;*	$Revision: 0.2 $																				*;
;*	$ASM: AVR GNU Assembler $																		*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Thursday, October 10, 2014 08:04:46 UTC $												*;
;*==================================================================================================*/

#define __ERRORBUF_LIB___

/*==================================================================================================*;
;*                                   I N C L U D E   H E A D E R S                                  *;
;*==================================================================================================*/

		.nolist
#include <avr/io.h>
#include <avr_macros.h>								//General purpose macros.
		.list
#include <errorbuf.h>								//Error buffer structure/data definitions.


/*==================================================================================================*;
;*                                         C O N S T A N T S                                        *;
;*==================================================================================================*/

// Size of error code buffer.
MAX_ERROR_ENTRIES = 8
MAX_ERROR_ENTRIES_BIT = 3


/*==================================================================================================*;
;*                                   L O C A L   V A R I A B L E S                                  *;
;*==================================================================================================*/
		.section .data

// Structure for storing/retrieving error codes.
err_dat:
		.space	MAX_ERROR_ENTRIES					;Error data queue.
// R6 holds the index in the error queue.
err_ovf:
		.byte	0									;Overflow flag.

/*==================================================================================================*;
;*                                  P R O G R A M   S E C T I O N                                   *;
;*==================================================================================================*/
		.section .text

/*--------------------------------------------------------------------------------------------------*;
;* error_flush: Flush the error code queue.															*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Flush the error code queue.																		*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	CF=0 and R24=0: OK.																				*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R6, R24.																						*;
;*																									*;
;*STACK USAGE:																						*;
;*	2 bytes total.																					*;
;*																									*;
;*NOTES:																							*;
;*	1.	R6 is holding the current head of queue position.											*;
;*--------------------------------------------------------------------------------------------------*/
		.func	error_flush
error_flush:
		push	ZL										;Save used registers. (2/4)
#if (RAMEND > 256)
		push	ZH
#endif
; Clear the index pointer and overflow flag.
		clr		R6										;Clear the index to head of queue. (1)
		sts		err_ovf,ZEROR							;Clear the overflow flag. (2)
		ldi		ZL,lo8(err_dat)							;Point Z at error buffer. (1/2)
#if (RAMEND > 256)
		ldi		ZH,hi8(err_dat)
#endif
		ldi		R24,MAX_ERROR_ENTRIES					;Get buffer size couter. (1)
1:		st		Z+,ZEROR								;Clear buffer position and bump pointer. (2)
		dec		R24										;Count down. (1)
		brne	1b										;Continue until end of buffer. (1/2)
; Restore and return OK.
		clr		R24										;Return result (R24=CF=0). (1)
#if (RAMEND > 256)
		pop		ZH										;Restore used registers and return. (6/8)
#endif
		pop		ZL
		ret
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
;* error_init: One time initialization of the error buffer (LIFO).									*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Initialize the error buffer by initializing all values to an empty state.						*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	CF=0, R24=0: OK.																				*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	4 bytes total, including function call.															*;
;*																									*;
;*NOTES:																							*;
;*	1.	Currently, initialization is the same as flushing the error buffer.							*;
;*	2.	R6 is holding the current head of queue position.											*;
;*--------------------------------------------------------------------------------------------------*/
		.func	error_init
error_init:
		rjmp	error_flush
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* error_push: Store an entry in the error queue.													*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Store a new entry (error code) in the error queue. No new entries are stored once the queue is	*;
;*	full (which triggers the overflow flag).														*;
;*	The queue can be used in interrupt routines, because interrupts are disabled during queue		*;
;*	manipulation to prevent corruption of the queue.												*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	R24 = error code to push on error queue (LIFO).													*;
;*																									*;
;*OUTPUT:																							*;
;*	CF=0: succeeded;																				*;
;*	CF=1: queue is full (overflow flag is set too).													*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	SREG[C].																						*;
;*																									*;
;*STACK USAGE:																						*;
;*	6 bytes total, including function calls.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	R6 is holding the current head of queue position.											*;
;*--------------------------------------------------------------------------------------------------*;
		.func	error_push
error_push:
		push	ZL									;Save used registers. (2/4)
#if (RAMEND > 256)
		push	ZH
#endif
; Point Z at error buffer. (2)
		ldi		ZL,lo8(err_dat)
#if (RAMEND > 256)
		ldi		ZH,hi8(err_dat)
#endif
; Check for overflow.
		ENTERCRITICAL
		sbrs	R6,MAX_ERROR_ENTRIES_BIT			;Max entries reached? (1/2)
		rjmp	1f									;  Continue if not. (2)
		sts		err_ovf,R6							;Set overflow flag if queue is full. (2)
		sec											;Return CF=1. (1)
		rjmp	_error_push_exit
; Store error code in queue (LIFO).
1:		add		ZL,R6								;Point at next location in error queue. (2)
#if (RAMEND > 256)
		adc		ZH,ZEROR
#endif
		st		Z,R24								;Store the error code. (2)
		inc		R6									;Update error queue index. (3)
		clc											;Return CF=0. (1)
; Return result in Carry Flag.
_error_push_exit:
		EXITCRITICAL
#if (RAMEND > 256)
		pop		ZH									;Restore and return. (6/8)
#endif
		pop		ZL
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* error_pop: Retrieve the most current entry (LIFO) from the queue and return it.					*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Retrieve the most current entry from the queue (LIFO) and return it.							*;
;*	The queue can be used in interrupt routines, because interrupts are disabled during queue		*;
;*	manipulation to prevent corruption of the queue.												*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = last pushed error code (LIFO), or 0 (OK) if no error codes in queue;						*;
;*	Z=1: no error code in queue, Z=0 if error code rerieved from LIFO queue.						*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	4 bytes total, including function calls.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	R6 is holding the current head of queue position.											*;
;*--------------------------------------------------------------------------------------------------*;
		.func	error_pop
error_pop:
		push	ZL										;Save used registers. (2/4)
#if (RAMEND > 256)
		push	ZH
#endif
; Point Z at error buffer. (2)
		ldi		ZL,lo8(err_dat)
#if (RAMEND > 256)
		ldi		ZH,hi8(err_dat)
#endif
; Check if queue empty.
		clr		R24										;Return OK (0), (1)
		tst		R6										;  if error queue is empty. (1)
		breq	_error_pop_exit
; Get last error code (LIFO) from buffer and update index.
		ENTERCRITICAL
		sts		err_ovf,ZEROR							;Clear the overflow flag. (2)
		dec		R6										;Decrement head of queue index. (1)
		add		ZL,R6									;Point at queue head. (2)
#if (RAMEND > 256)
		adc		ZH,ZEROR
#endif
		ld		R24,Z									;Get error code in R24. (2)
; Return the result (R24 and Z).
		EXITCRITICAL
		clz												;Clear Z flag. (1)
_error_pop_exit:
#if (RAMEND > 256)
		pop		ZH										;Restore used registers and return. (6/8)
#endif
		pop		ZL
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* error_peek: Return the most current entry, nothing is removed from the error queue.				*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Return the most current entry, nothing is removed from the error queue.							*;
;*	The queue can be used in interrupt routines, because interrupts are disabled during queue		*;
;*	manipulation to prevent corruption of the queue.												*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = last pushed error code (LIFO), or 0 (OK) if no error codes;								*;
;*	Z=1: no error code in queue, Z=0 if error code rerieved from head of queue.						*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24, TMPR.																						*;
;*																									*;
;*STACK USAGE:																						*;
;*	5 bytes total, including function calls.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	R6 is holding the current head of queue position.											*;
;*--------------------------------------------------------------------------------------------------*;
		.func	error_peek
error_peek:
		push	ZL										;Save used registers. (2/4)
#if (RAMEND > 256)
		push	ZH
#endif
; Point Z at error queue. (2)
		ldi		ZL,lo8(err_dat)
#if (RAMEND > 256)
		ldi		ZH,hi8(err_dat)
#endif
; Check if queue empty.
		clr		R24										;Return OK (0), (1)
		tst		R6										;  if error queue is empty. (1)
		breq	_error_peek_exit
; Get last error code (LIFO) from buffer, without updating the index.
		add		ZL,R6									;Point at queue head. (2)
#if (RAMEND > 256)
		adc		ZH,ZEROR
#endif
		ld		R24,-Z									;Get last error code in R24. (2)
; Return the result (R24 and Z).
		EXITCRITICAL
		clz												;Clear Z flag. (1)
_error_peek_exit:
#if (RAMEND > 256)
		pop	ZH											;Restore used registers and return. (6/8)
#endif
		pop		ZL
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* error_overflow: Check whether too many errors have occurred.										*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check whether too many errors have occurred.													*;
;*	The queue can be used in interrupt routines, because interrupts are disabled during queue		*;
;*	manipulation to prevent corruption of the queue.												*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	CF=0 and R24=0: No overflow;																	*;
;*	CF=1 and r24!=0: Error queue overflow.															*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	2 bytes total, including function calls.														*;
;*																									*;
;*NOTES:																							*;
;*	None.																							*;
;*--------------------------------------------------------------------------------------------------*;
		.func	error_overflow
error_overflow:
		lds		R24,err_ovf
		clc
		cpse	R24,ZEROR								;Test if overflow flag is set. (1/2)
		sec												;  If so, set Carry flag. (1)
		ret												;Return the result in CF and R24. (4)
		.endfunc

		.end
