/*===================================================================================================
 *SYNOPSIS:
 *	Header for FIFO and LIFO Queue processing functions for the Atmel AVR 8-bit MCUs.
 *
 *VERSION HISTORY:
 *	0.4 added dynamic memory allocation functions for buffer/queue allocation.
 *	0.3:	Added LIFO function for error code queueing library.
 *	0.2:	Split from source file to make it a library to include elsewhere.
 *	0.1:	Initial version.
 *
 *DESCRIPTION:
 *	Defines constants and functions used for handling a FIFO/LIFO Queue.
 *
 *NOTES:
 *	None.
 *
 *COPYRIGHT:
 *	(c)2014 by Ron Moerman.
 *	This program comes with ABSOLUTELY NO WARRANTY.
 *	This is free software, and you are welcome to redistribute it under certain conditions.
 *	The program and its source code are published under the GNU General Public License (GPL).
 *	See http://www.gnu.org/licenses/gpl-3.0.txt for details.
 *
 *	$File: queuelib.h $
 *	$Revision: 0.4 $
 *	$ASM: AVR GNU AS $
 *	$Author: Ron Moerman $
 *	$Email: ron@moerman.cc $
 *	$Date: Sunday, October 19, 2015 19:52:18 UTC $
 *==================================================================================================*/

#ifndef __QUEUELIB_H__
#define __QUEUELIB_H__ 1

/*===================================================================================================
 *                                   I N C L U D E   H E A D E R S
 *==================================================================================================*/
//#define __SFR_OFFSET 0
#include <avr_macros.h>									//General purpose assembler macros.

/*===================================================================================================
 *                                         C O N S T A N T S
 *==================================================================================================*/
//--- Queue limits.
#define QUEUE_MAX_LEN	64            //Maximum length of queue data buffer.
#define QUEUE_MIN_LEN	4             //Minumim length of queue data buffer.
//--- Queue error codes.
#define ERR_QUEUE_LOCKED 0x81
#define ERR_QUEUE_EMPTY 0x82
#define ERR_QUEUE_FULL 0x84
#define ERR_QUEUE_SIZE 0x85

/*===================================================================================================
 *                              R E G I S T E R   D E F I N I T I O N S
 *==================================================================================================*/
#ifndef RETR
 #define RETR R24									  //Register for function return value.
#endif
// Queue parameter registers.
#define QDR R24                     //Queue data byte register.
#define QER R24                     //Queue function error code return register.
#define QPR Z                       //Queue structure register.
#define QPRH ZH
#define QPRL ZL
#define QBR X                       //Queue data buffer register.
#define QBRH XH
#define QBRL XL

#endif /* __QUEUELIB_H__ */
