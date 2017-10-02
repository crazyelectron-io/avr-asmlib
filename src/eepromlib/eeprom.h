/*==================================================================================================*;
;*SYNOPSIS:																							*;
;*	Header file for interrupt driven buffered EEPROM reading and writing library routines for 8-bit	*;
;*	AVR MCUs.																						*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	20141031 v0.1	Initial test version.															*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Defines constants and function prototypes for reading, writing and erasing the EEPROM memory in	*;
;*	8-bit AVR MCUs.																					*;
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
;*	$File: eeprom.h $																				*;
;*	$Revision: 0.1 $																				*;
;*	$ASM: AVR-GCC AS $																				*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Thursday, October 31, 2014 19:21:24 UTC $												*;
;*==================================================================================================*/

#ifndef ___EEPROM_H___
#define ___EEPROM_H___


/*==================================================================================================*;
;*                                         C O N S T A N T S                                        *;
;*==================================================================================================*/



/*==================================================================================================*;
;*                               F U N C T I O N   P R O T O T Y P E S                              *;
;*==================================================================================================*/

/*--------------------------------------------------------------------------------------------------*;
;* ee_init: Initialize the EEPROM Address and Data Buffer with 0xFF.								*;
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
#ifndef ___EEPROM_LIB___
		.extern ee_init
#else
		.global ee_init
#endif


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
#ifndef ___EEPROM_LIB___
		.extern ee_readbyte
#else
		.global ee_readbyte
#endif


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
#ifndef ___EEPROM_LIB___
		.extern	ee_writebyte
#else
		.global ee_writebyte
#endif

#endif //___EEPROM_H___



