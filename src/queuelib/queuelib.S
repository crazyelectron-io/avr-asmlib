/*==================================================================================================*;
;*SYNOPSIS:
;*	Basic FIFO and LIFO Queue processing functions for AVR 8-bit MCUs.
;*
;*VERSION HISTORY:
;*	0.4 added dynamic memory allocation functions for buffer/queue allocation.
;*	0.3 added LIFO function for error queueing functions.
;*	0.2 changed to library.
;*	0.1	Initial test version.
;*
;*DESCRIPTION:
;*	Routines for FIFO/LIFO Queue reading, writing and initialization. The queue consists of a
;*	memory structure and a buffer to store the bytes stored in, or extracted from, the queue.
;*	The maximum queue buffer size is 254 bytes and the minimum size is 8 bytes.
;*	The queue reading and writing routines are interrupt proof by utilizing a lock byte to be
;*	respected by any (interrupt service) routine that wants to read or write the fifo queue.
;*
;*NOTES:
;*	None.
;*
;*COPYRIGHT:
;*	(c)2014 by Ron Moerman, All Rights Reserved.
;*
;*	This program comes with ABSOLUTELY NO WARRANTY.
;*	This is free software, and you are welcome to redistribute it under certain conditions.
;*	The program and its source code are published under the GNU General Public License (GPL).
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.
;*
;*	$File: queue.S $
;*	$Revision: 0.4 $
;*	$ASM: AVR GNU AS $
;*	$Author: Ron Moerman $
;*	$Email: ron@moerman.cc $
;*	$Date: Sunday, October 19, 2014 09:46:17 UTC $
;*==================================================================================================*/

/*==================================================================================================*;
;*                                   I N C L U D E   H E A D E R S                                  *;
;*==================================================================================================*/

#include <avr/io.h>
#include <avr_macros.h>								//General purpose macros.
#include <heap.h>									//Memory allocation functions.
#include <queue.h>									//Queue structure/data definitions.


/*==================================================================================================*;
;*                                   L O C A L   C O N S T A N T S									*;
;*==================================================================================================*/

// Queue data structure offset values.
#define Q_LOCK 0										//Queue locked flag (0x00=Unlocked, 0xFF=Locked).
#define Q_SIZE (Q_LOCK+1)								//Data buffer length.
#define Q_COUNT (Q_SIZE+1)								//Element number.
#define Q_IN (Q_COUNT+1)								//Insertion point offset.
#define Q_OUT (Q_IN+1)									//Extraction point offset.
#define Q_OVF (Q_OUT+1)									//Non-zero indicates buffer overflow.
#define Q_BUFF (Q_OVF+1)								//Address of data buffer.
// Size of queue structure.
#define QUEUE_STRUCT_SIZE (Q_BUFF+2)


/*==================================================================================================*;
;*                                L I N K E R   D E F I N I T I O N S								*;
;*==================================================================================================*/

// Make these library funtions externally accessible.
		.global queue_init
		.global queue_free
		.global queue_flush
		.global queue_put
		.global	queue_get
		.global queue_length


/*==================================================================================================*;
;*                                  P R O G R A M   S E C T I O N									*;
;*==================================================================================================*/
		.section .text

/*------------------------------------------------------------------------------*;
 * queue_init: Set up an empty FIFO/LIFO queue structure.						*;
 *------------------------------------------------------------------------------*;
 *DESCRIPTION:
 *	Set up a new FIFO/LIFO queue by initializing all values to an 'empty queue'
 *	state. The memory for the queue structure and the data buffer is dynamically
 *	allocated from heap memory.
 *
 *INPUT:
 *	R24	= Queue data buffer size (should be >=4 and <=64).
 *
 *OUTPUT:
 *	CF=0: Succeeded; CF=1: Error occurred (R24 holds the error code on exit);
 *	Z = Address of allocated and initialized queue (if CF=0).
 *
 *REGISTERS CHANGED:
 *	R24, TMPR, Z.
 *
 *STACK USAGE:
 *	~16 bytes.
 *
 *NOTES:
 *	1. It is assumed that no ISR tries to access the Queue during initialization.
 *------------------------------------------------------------------------------*/
.func	queue_init
queue_init:
		PUSHM	R25,XL,XH								;Save used registers.
		mov		R25,R24									;Save queue data buffer length.
; First, allocate the queue structure.
1:		ldi		R24,QUEUE_STRUCT_SIZE
		rcall	heap_alloc							;Allocate the queue structure.
		brcs	queue_init_exit					;Quit if error allocating queue structure.
; Initialize the queue structure.
		movw	ZL,XL										;Queue address in Z.
		std		Z+Q_SIZE,R25						;Store size of queue buffer.
		rcall	queue_flush							;Clear the pointers and counters in the Queue.
; Allocate the queue data buffer.
		mov		R24,R25
		rcall	heap_alloc
		brcc	queue_init_fill
; If alloc failed, free the previously allocated queue structure before returning.
		movw	XL,ZL										;Get the queue pointer @X.
		push	R24											;Save allocation error code.
		rcall	heap_free								;Give queue structure back to heap memory.
		pop		R24											;Restore initial error code.
		rjmp	queue_init_err					;Return with error.
; If succeeded, save the queue data buffer address in the queue structure.
queue_init_fill:
		std		Z+Q_BUFF,XL
		std		Z+Q_BUFF+1,XH						;Store buffer address in Queue structure.
; Restore and return.
		clc
queue_init_exit:
		POPM	R25,XL,XH
		ret
.endfunc


/*------------------------------------------------------------------------------*;
;* queue_free: Release a queue structure and data buffer.						*;
;*------------------------------------------------------------------------------*;
;*DESCRIPTION:
;*	Release the previously initialized queue memory (structure and data buffer).
;*
;*INPUT:
;*	Z (QPR)	= Address of Queue structure.
;*
;*OUTPUT:
;*	CF=0: Succeeded; CF=1: Error occurred (R24 holds the error code).
;*
;*REGISTERS CHANGED:
;*	R24, TMPR.
;*
;*STACK USAGE:
;*	12 bytes.
;*
;*NOTES:
;*	1.	It is assumed that no ISR tries to access the FIFO Queue during/after
;*			this routine.
;*------------------------------------------------------------------------------*/
.func	queue_free
queue_free:
		PUSHM	XL,XH										;Save used registers.
; Free queue data buffer memory.
		ldd		XL,QPR+Q_BUFF
		ldd		XH,QPR+Q_BUFF+1
		rcall	heap_free
		brcs	1f											;Exit if error.
; Free queue structure memory.
		movw	XL,QPRL
		rcall	heap_free
; Restore and return result.
1:		POPM	XL,XH
		ret
.endfunc


/*------------------------------------------------------------------------------*;
;* queue_flush: Reset the queue pointers and counters to 'empty'.				*;
;*------------------------------------------------------------------------------*;
;*DESCRIPTION:
;*	Reset the queue pointers and counters to 'empty queue'.
;*
;*INPUT:
;*	Z = Address of queue to flush.
;*
;*OUTPUT:
;*	None.
;*
;*REGISTERS CHANGED:
;*	TMPR.
;*
;*STACK USAGE:
;*	3 bytes.
;*
;*NOTES:
;*	1.	The lock flag is ignored (and reset) during queue flush.
;*------------------------------------------------------------------------------*/
		.func queue_flush
queue_flush:
		ENTERCRITICAL
		std		QPR+Q_COUNT,ZEROR			;Clear queue byte counter.
		std		QPR+Q_IN,ZEROR			 	;Reset buffer head and tail index.
		std		QPR+Q_OUT,ZEROR
		std		QPR+Q_OVF,ZEROR
		std		QPR+Q_LOCK,ZEROR			;Clear the lock byte.
		EXITCRITICAL
		ret
		.endfunc


/*------------------------------------------------------------------------------*;
;* queue_put: Put a byte in the FIFO/LIFO queue (@Z) at next free position.		*;
;*------------------------------------------------------------------------------*;
;*DESCRIPTION:
;*	Put a byte in the FIFO/LIFO queue (@Z) at next free position. Any error code
;*	is returned in R24 (if the queue is full or locked) and the carry flag is
;*	set to indicate the error to the calling program.
;*
;*INPUT:
;*	Z = Address of queue structure to store read data byte;
;*	R24 = byte to store in the queue.
;*
;*OUTPUT:
;*	CF=0: Succeeded, R24 = byte stored in queue;
;*	CF=1: Queue full or locked, R24 = error code.
;*
;*REGISTERS CHANGED:
;*	R24 returns byte stored (CF=0) or error code (CF=1).
;*
;*STACK USAGE:
;*	7 bytes.
;*
;*NOTES:
;*	1.	This routine is ISR-proof and only disables interrupts while needed to
;*			(un)lock the queue.
;*------------------------------------------------------------------------------*/
		.func queue_put
queue_put:
		PUSHM	R18,R19,YL,YH							;Save used registers.
; Check if queue currently locked.
		ENTERCRITICAL
		ldd		R18,Z+Q_LOCK							;Check lock: 0=Unlocked, !0=Locked.
		tst		R18
		breq	0f
		EXITCRITICAL
		ldi		QER,ERR_QUEUE_LOCKED					;Queue is locked, set error code and exit.
		rjmp	_queue_error
; Lock the queue for save insertion.
0:		ser		R18
		std		Z+Q_LOCK,R18							;Set lock byte.
		EXITCRITICAL
;
; Check if the queue is full.
		ldd		R18,Z+Q_COUNT
		ldd		R19,Z+Q_SIZE
		cp		R18,R19									;Max. number of bytes already in queue?
		breq	_queue_full
;
; Store byte at insertion point in queue and bump pointer.
		ldd		R18,Z+Q_IN								;Calculate insertion address.
		ldd		YL,Z+Q_BUFF								;Y = buffer address.
		ldd		YH,Z+(Q_BUFF+1)
		clr		R19
		add		YL,R18
		adc		YH,R19
		st		Y,QDR									;Queue_buff[Q_IN++] = byte.
		inc		R18
;
; Check for end of queue buffer condition.
		ldd		R19,Z+Q_SIZE							;Reached end of queue buffer?
		cp		R19,R18
		brne	2f										;  No, continue,
		clr		R18										;  Yes, reset insertion point.
2:		std		Z+Q_IN,R18								;Update insertion index.
		ldd		R18,Z+Q_COUNT
		inc		R18										;Update queue counter.
		std		Z+Q_COUNT,R18
;
; Return OK (CF=0) after succesful processing of queue action.
_queue_done:
		clr		R18
		std		Z+Q_LOCK,R18							;Unlock the queue.
		clc
		rjmp	_queue_exit								; And return OK.
;
; Queue is full. Unlock and exit with error code.
_queue_full:
		ldi		QER,ERR_QUEUE_FULL
		clr		R18
		std		Z+Q_LOCK,R18
;
; Queue is locked, full or empty. Exit with error.
_queue_error:
		sec												;Return CF=1 to indicate error (R24=error code).
; Done restore and exit.
_queue_exit:
		POPM	YH,YL,R19,R18
		ret
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
;* queue_get: Read next byte (FIFO) from the queue @Z.												*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Read next byte from the FIFO queue @Z. Any error code is returned in R24 (if the queue is empty	*;
;*	or locked) and the carry flag is set to indicate the error to the calling program.				*;
;*																									*;
;*INPUT:																							*;
;*	Z (QPR) = Address of queue to read next data byte from.											*;
;*																									*;
;*OUTPUT:																							*;
;*	CF=0:	Succeeded;																				*;
;*	CF=1:	Queue emtpy or locked;																	*;
;*	R24 (QDR) = byte retrieved from queue, or error code (if CF=1).									*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24 (QDR/QER) returns data byte or error code.													*;
;*																									*;
;*STACK USAGE:																						*;
;*	7 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.	*;
;*--------------------------------------------------------------------------------------------------*/
		.FUNC queue_get
queue_get:
		PUSHM	R18,R19,YL,YH
;
; Check if queue is currently locked.
		ldi		QER,ERR_QUEUE_LOCKED
		ENTERCRITICAL
		ldd		R18,Z+Q_LOCK							;Check lock flag: 0=Unlocked, !0=Locked.
		tst		R18
		breq	0f
		EXITCRITICAL
		rjmp	_queue_error							;Queue is locked, exit with ERR_QUEUE_LOCKED.
; Lock the queue for safe reading of (FIFO) data byte.
0:		std		QPR+Q_LOCK,R24							;Set the lock flag to non-zero.
		EXITCRITICAL
;
; Check if the queue is empty.
		ldd		R18,QPR+Q_COUNT
		tst		R18
		breq	_queue_empty
;
; Read byte at extraction point in queue and bump the pointer.
		ldd		YL,QPR+Q_BUFF							;Y = buffer address.
		ldd		YH,QPR+(Q_BUFF+1)
		ldd		R18,QPR+Q_OUT							;Calculate extraction address.
		clr		R19
		add		YL,R18									;Y = buffer address + index.
		adc		YH,R19
		ld		QDR,Y									;Data byte = queue_buff[Q_OUT++].
		inc		R18
;
; Check for end of queue buffer condition.
		ldd		R19,QPR+Q_SIZE							;Reached end of queue buffer?
		cp		R19,R18
		brne	1f										; No, continue,
		clr		R18										; Yes, reset extraction point.
1:		std		QPR+Q_OUT,R18							;Update extraction index.
		ldd		R18,QPR+Q_COUNT
		dec		R18										;Update queue counter.
		std		QPR+Q_COUNT,R18
;
; Return OK (CF=0) after succesful read of data byte from queue.
		rjmp	_queue_done
;
; Queue is empty. Unlock, set error code and exit.
_queue_empty:
		std		QPR+Q_LOCK,R18							;Reset lock flag (R18=0).
		ldi		QER,ERR_QUEUE_EMPTY
		rjmp	_queue_error							;Return with error status.
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
 * queue_length: Get # of bytes stored in queue buffer.												*;
 *--------------------------------------------------------------------------------------------------*;
 *DESCRIPTION:
 *		Get # of bytes stored in queue pointed at by Z.
 *INPUT:
 *		Z (QPR) = Address of queue structure to return length of data from.
 *OUTPUT:
 *		R24 (QDR) = length of queue data stored in queue.
 *REGISTERS USED:
 *		R24.
 *STACK USAGE:																						*;
;*	7 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.	*;
;*--------------------------------------------------------------------------------------------------*/
		.func queue_length
queue_length:
		ldd	R24,Z+Q_COUNT
		ret
		.endfunc

		.end
