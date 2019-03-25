/*==================================================================================================*;
;*SYNOPSIS: 																						*;
;*	Simple heap memory allocation and deallocation library routines.								*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	0.1	Initial version.																			*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Simple heap memory allocation routines for small 8-bit AVR MCU's that have limited amounts of	*;
;*	SRAM but still need some form of dynamic memory.												*;
;*	Please note, that there is virtually no error checking and whenever memory outside the			*;
;*	allocated block is written, the heap will get corrupted.										*;
;*																									*;
;*NOTES:																							*;
;*	The maximum block size is limited to 127 bytes and the total heap size is limited to 255 bytes.	*;
;*																									*;
;*COPYRIGHT:																						*;
;*	(c)2014 by Ron Moerman, All Rights Reserved.													*;
;*																									*;
;*	This program comes with ABSOLUTELY NO WARRANTY.													*;
;*	This is free software, and you are welcome to redistribute it under certain conditions.			*;
;*	The program and its source code are published under the GNU General Public License (GPL).		*;
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.										*;
;*																									*;
;*	$File: heap.h $																					*;
;*	$Revision: 0.1 $																				*;
;*	$ASM: GNU GCC AS $																				*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Sunday, October 19, 2014 08:44:12 UTC $													*;
;*==================================================================================================*/

/*==================================================================================================*;
;*                                   I N C L U D E   H E A D E R S                                  *;
;*==================================================================================================*/

#include <avr/io.h>
#include <avr_macros.h>									//General purpose macros.
#include <heap.h>										//Library definitions for using the heap functions.


/*==================================================================================================*;
;*                                         C O N S T A N T S                                        *;
;*==================================================================================================*/

//--- Define number of bytes dedicated to heap memory management.
.ifndef HEAP_SIZE
 .if (RAMEND > 0x100)
	HEAP_SIZE = 255										;255 bytes for MCU's with 512 bytes or more SRAM.
 .elsif (RAMEND > 0x80)
	HEAP_SIZE = 128										;128 bytes for MCU's with 256 bytes SRAM.
 .else
	HEAP_SIZE = 80										;80 bytes for MCU's with less than 256 bytes SRAM.
 .endif
.endif


/*==================================================================================================*;
;*                                L I N K E R   D E F I N I T I O N S                               *;
;*==================================================================================================*/

//--- Make these library funtions externally accessible.
		.global heap_alloc
		.global heap_free


/*==================================================================================================*;
;*                                  L O C A L   V A R I A B L E S                                   *;
;*==================================================================================================*/
		.section .data

//--- Reserve the heap variables and storage.
heap_initialized:
		.byte	0										;Flag indicating if the heap has been initialized.
heap_head:
		.byte	0,0										;Pointer to head of free blocks list.
heap_start:
		.byte	HEAP_SIZE								;Set blok size to heap size.
		.byte	0,0										;Pointer to next free block.
		.space	HEAP_SIZE-HEAP_MIN_SIZE					;Reserve heap memory.
heap_end:


/*==================================================================================================*;
;*                                  P R O G R A M   S E C T I O N                                   *;
;*==================================================================================================*/
		.section .text

/*--------------------------------------------------------------------------------------------------*;
;* heap_init: Set up the heap area as an empty (free) block of memory.								*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Set up the heap area as an empty (free) block of memory.										*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	None.																							*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	TMPR.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	? bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1. It is assumed that no ISR tries to access the heap during initialization.					*;
;*--------------------------------------------------------------------------------------------------*/
		.func	heap_init
heap_init:
		PUSHM	YL,YH
; Set initial size of heap.
		ldi		YL,lo8(heap_start)						;Point at start of heap
		ldi		YH,hi8(heap_start)
		ldi		TMPR,HEAP_SIZE
		st		Y+,TMPR									;Set size of heap free block.
; Clear pointer to next free block.
		st		Y,ZEROR
		std		Y+1,ZEROR
; Set first free memory block address.
		sts		heap_head,YL
		sts		heap_head+1,YH
; Set heap initialized flag.
		ser		TMPR
		sts		heap_initialized,TMPR
; Restore and reurn.
		POPM	YL,YH
		clc
		ret
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
;* heap_garbage: Do garbage collection on the heap.													*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Do garbage collection on the heap.																*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	None.																							*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	TMPR, X, Y, Z.																					*;
;*																									*;
;*STACK USAGE:																						*;
;*	3 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1. It is assumed that no ISR tries to access the heap during initialization.					*;
;*--------------------------------------------------------------------------------------------------*/
		.func	heap_garbage
heap_garbage:
		push	R19
; Point Y at start of free blocks list.
heap_garbage_again:
		lds		YL,heap_head
		lds		YH,heap_head+1
; Are we at end of free list?
heap_garbage_loop:
		cp		YL,YH
		breq	heap_garbage_end
; Check if next free block is adjacent to this free block.
		ld		TMPR,-Y									;Get size of this free block.
		movw	ZL,YL									;Calculate start of next free block.
		inc		TMPR									;  Include length bytes.
		inc		TMPR
		add		ZL,TMPR									;  Add length of free block.
		adc		ZH,ZEROR
		ldd		XL,Y+1									;Get pointer to next free block.
		ldd		XH,Y+2
		cp		XL,ZL									;Is the next block adjacent?
		brne	heap_garbage_next
		cp		XH,ZH
		brne	heap_garbage_next
; Merge two adjacent blocks and adjust size of new block.
		ld		ZL,X+									;Retrieve pointer to next free block.
		ld		ZH,X
		ld		R19,-X									;Bump pointer back.
		ld		R19,-X									;Get length of 2nd block to merge.
		dec		TMPR									;Don't count first length byte.
		add		TMPR,R19
		st		Y,TMPR									;Save new length of merged free block.
		std		Y+1,ZL									;Update next free block pointer.
		std		Y+2,ZH
; Two blocks merged, start over.
		rjmp	heap_garbage_again
; Retreive next free block address.
heap_garbage_next:
		ldd		ZL,Y+1
		ldd		ZH,Y+2
		movw	YL,ZL
		rjmp	heap_garbage_loop
heap_garbage_end:
		pop		R19
		ret
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
;* heap_alloc: Allocate the speficied amount of memory from the heap.								*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Allocate the specified amount of memory and return pointer to it, or CF=1 if not enough	free	*;
;*	memory available.																				*;
;*																									*;
;*INPUT:																							*;
;*	R24 = Size of memory block to allocate.															*;
;*																									*;
;*OUTPUT REGISTERS:																					*;
;*	CF=0: Succeeded; CF=1: Error;																	*;
;*	R24 = error code (only if CF=1);																*;
;*	X = address of allocated memory block (if CF=0).												*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	TMPR, X ,R24 (only if error).																	*;
;*																									*;
;*STACK USAGE:																						*;
;*	12 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	This function is only for internal use from the heap_alloc routine.								*;
;*--------------------------------------------------------------------------------------------------*/
		.func	heap_alloc
heap_alloc:
		PUSHM	YL,YH,ZL,ZH
; Check if heap already initialized.
		lds		TMPR,heap_initialized
		sbrs	TMPR,7
		rcall	heap_init
; Check if requested memory block size is within range.
		cpi		R24,HEAP_MAX_SIZE+1						;Requested block too large?
		brsh	heap_alloc_err1
		cpi		R24,HEAP_MIN_SIZE						;Or too small?
		brlo	heap_alloc_err1
; Get address of start of heap pointer (minus 1).
		ldi		YL,lo8(heap_head-1)
		ldi		YH,hi8(heap_head-1)
		rjmp	heap_alloc_next							;Go check free block pointer.
; Walk through free block list until we find a big enough block (or reach the end).
heap_alloc_walk:
		ld		TMPR,-Y									;Get size of free block.
		inc		TMPR									;Is this free memory block big enough?
		cp		R24,TMPR
		brsh	heap_alloc_next							;If not, go check next block.
; Found big enough block, get our part of it.
		ld		TMPR,Y+									;Restore Y pointer and length of free block.
		PUSHY											;Save address of block to return.
; Get current free block pointer.
		ld		XL,Y
		ldd		XH,Y+1
; Is memory block just the right size?
		cp		R24,TMPR								;Block same size (within HEAP_MIN_SIZE range)
		brne	1f
heap_alloc_fit:
		movw	YL,XL									;Set insertion point to previous free block pointer,
		rjmp	heap_alloc_ins							; and go insert it there.
1:		subi	TMPR,HEAP_MIN_SIZE
		cp		R24,TMPR
		brsh	heap_alloc_fit
		subi	TMPR,-(HEAP_MIN_SIZE)					;Correct size of free memory block.
; Init newly allocated block and the remaining port of free block.
		st		-Y,R24									;Set size of new allocated memory block.
		ld		R24,Y+									;Bump pointer back.
		add		YL,R24									;Point at size byte of new free block.
		adc		YH,ZEROR
		sub		TMPR,R24								;Decrease size of free memory with allocated size.
		dec		TMPR									;Take size byte into account.
		st		Y+,TMPR									;Set size of remaining free block and bump pointer.
		st		Y,XL									;Save next free pointer in remaining block.
		std		Y+1,XH
heap_alloc_ins:
		st		Z,YL									;Update free block list pointer.
		std		Z+1,YH
		POPX											;Retrieve address of allocated block.
		rjmp	heap_alloc_done
; Go to next free block in list.
heap_alloc_next:
		movw	ZL,YL									;Save address of previous block in Z.
		ld		TMPR,Z+									;Bump pointer past length byte.
		ld		YL,Z									;Get pointer to next free block.
		ldd		YH,Z+1
		cp		YL,YH									;Check if end of heap reached.
		brne	heap_alloc_walk
; We're at the end of the heap; found nothing.
; Return error.
		ldi		R24,HEAP_ERR_FULL
		rjmp	_heap_alloc_err2
; Invallid heap alloc size, return error.
heap_alloc_err1:
		ldi		R24,HEAP_ERR_SIZE
_heap_alloc_err2:
		clr		XL										;Return NULL pointer,
		clr		XH
		sec												; and return CF=1.
		rjmp	heap_alloc_exit
; Succeed, return address.
heap_alloc_done:
		clc
heap_alloc_exit:
		POPM	YL,YH,ZL,ZH
		ret
		.endfunc


/*--------------------------------------------------------------------------------------------------*;
;* heap_free: Free the specified memory block.														*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Free the specified memory block (X) and put it in the list of free memory blocks at the right	*;
;*	point to make garbage collection possible.														*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	X = Address of memory block to return to the heap.												*;
;*																									*;
;*OUTPUT REGISTERS:																					*;
;*	X = NULL.																						*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	TMPR, X.																						*;
;*																									*;
;*STACK USAGE:																						*;
;*	7 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1.	After returning the memory block to the free list, the garbage collection routine is called	*;
;*		to merge adjacent blocks of memory.															*;
;*--------------------------------------------------------------------------------------------------*/
		.func	heap_free
heap_free:
; Save used registers.
		PUSHM	ZL,ZH,YL,YH
; Point Z at free heap list header (minus 1).
		ldi		ZL,lo8(heap_head)
		ldi		ZH,hi8(heap_head)
; Should we insert the new free memory block before the current free block in the list?
heap_free_loop:
		cp		ZL,XL									;Block to add is below current free block?
		cpc		ZH,XH
		brlo	heap_free_next							;If not, go check next free block in list.
; Insert memory block here.
		st		Y,XL									;Store pointer to new memory block in list.
		std		Y+1,XH
		st		X+,ZL									;Store pointer to next free block in current free block.
		st		X,ZH
		rjmp	heap_free_exit							;We're done.
; Go check next free block.
heap_free_next:
		movw	YL,ZL									;Save free block list pointer in Y.
		ld		ZL,Y									;Retrieve next free block pointer.
		ldd		ZH,Y+1
; Are we at end of free memory blocks list?
		cp		ZL,ZH
		brne	heap_free_loop
; End of free heap reached, add block here.
		st		Y,XL									;Store next free block address in existing last free block.
		std		Y+1,XH
; Clear next free block pointer (indicating end of list).
heap_free_end:
		st		X+,ZEROR
		st		X,ZEROR
; Done. Start garbage collection before return.
heap_free_exit:
		rcall	heap_garbage
		clr		XL										;Return NULL to indicate block no longer valid.
		clr		XH
		POPM	ZL,ZH,YL,YH
		ret
		.endfunc

		.end
