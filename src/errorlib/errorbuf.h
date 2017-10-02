/*==================================================================================================*;
;*SYNOPSIS:																							*;
;*	Header for error buffering library functions to store and retrieve multiple errors (up to 8)	*;
;*	for the Atmel AVR 8-bit MCUs.																	*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	0.2 changed to assembler and library.															*;
;*	0.1	Initial test version.																		*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Routines for error buffer writing and reading to store and retrieve multiple errors that		*;
;*	occur during data processing (like UART send/receive).											*;
;*	The error buffer holds up to MAX_ERR_ENTRIES error codes.										*;
;*																									*;
;*NOTES:																							*;
;*	None.																							*;
;*																									*;
;*COPYRIGHT:																						*;
;*	(c)2014 by Ron Moerman, All Rights Reserved.													*;
;*																									*;
;*	This program comes with ABSOLUTELY NO WARRANTY.													*;
;*	This is free software, and you are welcome to redistribute it under certain conditions.			*;
;*	The program and its source code are published under the GNU General Public License (GPL).		*;
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.										*;
;*																									*;
;*	$File: error.h $																				*;
;*	$Revision: 0.2 $																				*;
;*	$ASM: Atmel Studio 6.2 $																		*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Thursday, October 12, 2014 08:04:46 UTC $												*;
;*==================================================================================================*/

#ifndef ___ERRORBUF_H___
#define ___ERRORBUF_H___ 1

// These library funtions are globaly accessible.
		.global error_init
		.global error_flush
		.global error_push
		.global error_pop
		.global	error_peek

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
#ifndef ___ERRORBUF_LIB___
		.extern	error_flush
#else
		.global error_flush
#endif


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
#ifndef ___ERRORBUF_LIB___
		.extern	error_init
#else
		.global error_init
#endif


/*--------------------------------------------------------------------------------------------------*;
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
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___ERRORBUF_LIB___
		.extern	error_push
#else
		.global error_push
#endif


/*--------------------------------------------------------------------------------------------------*;
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
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___ERRORBUF_LIB___
		.extern	error_pop
#else
		.global error_pop
#endif


/*--------------------------------------------------------------------------------------------------*;
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
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___ERRORBUF_LIB___
		.extern	error_peek
#else
		.global error_peek
#endif


/*--------------------------------------------------------------------------------------------------*;
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
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___ERRORBUF_LIB___
		.extern	error_overflow
#else
		.global error_overflow
#endif

#endif //___ERRORBUF_H___
