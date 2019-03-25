/*==================================================================================================*;
;*SYNOPSIS:																							*;
;*	Header for Simple heap memory allocation and deallocation library routines.						*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	0.1	Initial test version.																		*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Simple heap memory allocation routines for small 8-bit AVR MCU's that have limited amounts of	*;
;*	SRAM but still need some form of dynamic memory.												*;
;*	Please note, that there is virtually no error checking and whenever memory outside the			*;
;*	allocated block is written, the heap will get corrupted.										*;
;*																									*;
;*NOTES:																							*;
;*	The maximum block size is limited to 127 bytes and the total heap size is fixed to 255 bytes.	*;
;*																									*;
;*COPYRIGHT:																						*;
;*	(c)2014 by Ron Moerman, All Rights Reserved.													*;
;*																									*;
;*	This program comes with ABSOLUTELY NO WARRANTY.													*;
;*	This is free software, and you are welcome to redistribute it under certain conditions.			*;
;*	The program and its source code are published under the GNU General Public License (GPL).		*;
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.										*;
;*																									*;
;*	$File: heap.S $																					*;
;*	$Revision: 0.1 $																				*;
;*	$ASM: GNU GCC AS $																				*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Thursday, October 17, 2014 20:28:34 UTC $												*;
;*==================================================================================================*/


/*==================================================================================================*;
;*                                         C O N S T A N T S                                        *;
;*==================================================================================================*/

//--- Define constants related to heap block structures.
HEAP_MAX_SIZE = 64										;Maximum block size is 64 (1 size byte).
HEAP_MAX_DATA_SIZE = HEAP_MAX_SIZE-1					;Maximum effective block size returned.
HEAP_MIN_SIZE = 3										;Size field + next field

//--- Error codes
HEAP_ERR_FULL = 0x40
HEAP_ERR_SIZE = 0x41
HEAP_ERR_ADDR = 0x42


/*==================================================================================================*;
;*                              F U N C T I O N   P R O T O T Y P E S								*;
;*==================================================================================================*/

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
;*	R24 = error code (of CF=1);																		*;
;*	X = address of allocated memory block.															*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	TMPR, X ,R24 (if error).																		*;
;*																									*;
;*STACK USAGE:																						*;
;*	12 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	This function is only for internal use from the heap_alloc routine.								*;
;*--------------------------------------------------------------------------------------------------*/
		.extern	heap_alloc

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
		.extern	heap_free

