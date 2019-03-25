 /*==================================================================================================*
 *SYNOPSIS:
 *	Include file for use of Atmel AVR Library of RS485 Master and Slave functions.
 *
 *VERSION HISTORY:
 *	20140922 v0.1	Initial test version.
 *
 *DESCRIPTION:
 *	Header file for RS485 Master and Slave Library routines (for AVR 8-bit MCU with hardware USART).
 *	This Library supports up to 127 slaves on a single RS485 bus to communicate in master/slave style.
 *	RS485 is a half duplex differential serial bus and all communication is following the 'Request
 *	followed by Response' pattern from Master to Slave (except for Broadcast messages that are never
 *	answered by a Response message from a Slave).
 *
 *	The frame format is fixed at 9N1: 1 start bit, 9 data bits, no parity and 1 stop bit.
 *	The 9h bit is never used (0) by the Slaves. The Master makes use of it (making it 1) to
 *	indicate an address byte is being sent. All other data is sent by the Master with the 9th bit
 *	set to zero (0). This is to support the AVR Multi-Processor Communication Mode (MPCM) whereby
 *	the USART in the Slaves ignore any frame except address bytes with the 9th bit set. If it is the
 *	Slaves address, it will start receiving the other bytes until all frames of a message are
 *	received; then it will switch back to MPCM mode waiting for an address frame.
 *	The MPCM mode frees the Slaves from filtering data bytes not meant for them, so they can spent
 *	their time on more important tasks.
 *
 *	Currently only the ATtiny2313(A) MCU devices are supported. Besides the USART of the
 *	ATtiny2313(A), the port pin PD3 (can be redefined at Library compile time) is used to switch
 *	directions on the RS485 transceiver. PD0 (RXD)and PD1 (TXD) are used by the USART as Receive
 *	and Transmit lines.
 *
 *	The RS485 library supports two types of messages: Request & Response.
 *
 * REQUEST MESSAGES:
 *	Request messages do have the following structure, where the number of data bytes is currently
 *	limited to eight. You can change that limit by adapting the definition of NB_PARAM_BYTES.
 *	You can adapt the library to your application by setting an application specific value for
 *	NB_PARAM_BYTES in your makefile. Don't change anything if you can live with eight bytes.
 *
 *  +----+
 *  |  0 | - Address (0-128)
 *  +----+
 *  |  1 | - Command (0-255)
 *  +----+
 *  |  2 | - Number of parameters (0-8)
 *  +----+
 *  |  3 | - First parameter (0-255)
 *  +----+
 *  |  3 | - Second parameter (0-255)
 *  +----+
 *  |    |
 *   ...
 *  |    |
 *  +----+
 *  | 10 | - Eighth parameter (0-255)
 *  +----+
 *
 *	Please note that the address byte has the following structure:
 *	+----+----+----+----+----+----+----+----+
 *	|RESP|ADR6|ADR5|ADR4|ADR3|ADR2|ADR1|ADR0|
 *	+----+----+----+----+----+----+----+----+
 *   MSB                                LSB
 *
 *	Seven bits (ADR0->ADR6) are used to encode the address of the Slave.
 *	The high bit (RESP) is used to indicate if a response by the Slave is required.
 *	RESP=1 means "Response required", RESP=0 means "don't send Response".
 *	The broadcast message uses address zero (0).
 *	The RESP bit is zero there, hence no response is expected which is the expected behavior for
 *	broadcast. RESP cannot be set in case of broadcast address.
 *
 * RESPONSE MESSAGES:
 *	Response messages do have the following structure, where the number of data bytes currently is
 *	limited to 8. You can change that limit by adapting the definition of NB_RET_BYTES.
 *	You can adapt the library to your application by setting an application specific value for
 *	NB_RET_BYTES in your makefile. Don't change anything if you can live with eight bytes.
 *
 *	+----+
 *	|  0 | - Number of return values (0-8)
 *	+----+
 *	|  1 | - First return value (0-255)
 *	+----+
 *	|  3 | - Second return value (0-255)
 *	+----+
 *	|    |
 *	 ...
 *	|    |
 *	+----+
 *	|  8 | - Eighth return value (0-255)
 *	+----+
 *
 * USED MAKEFILE ENTRIES:
 *	 Name				   | Explanation										   | Default value
 *	-----------------------+-------------------------------------------------------+---------------
 *	 F_CPU					 Clock frequency in Hz.									 8000000
 *	 BAUD					 Baud rate, typical baud rates are 9600, 19200, 38400.	 38400
 *							 Not all baud rates can be produced depending on the
 *							 given MCU clock. Use a baud crystal (e.g. 14.7456 MHz)
 *							 to produce all standard baud rates with no error.
 *							 The compiler will issue a warning in case CPU clock
 *							 and baud rate do not match (error rate to high).
 *	 RS485_SWITCHING_DELAY	 Delay in ms. Short delay will be performed after		 5
 *							 receiving the last byte from the request and
 *							 switching the Slave bus transceiver to send mode.
 *
 *NOTES:
 *	Example usage of the Slave library routines:
 *
 *	include "RS485Lib.h"
 *	...Initialize MCU hardware (except USART)...
 *	rs485Initialize(Slave address);
 *	while (TRUE)
 *	{
 *		if (rs485MessageAvailable())
 *		{
 *			rs485Message* pRequest;
 *
 *			rs485ConsumeRequest(pRequest);
 *			....Do the requested processing...
 *			if (isResponseRequired(&pRequest))
 *			{
 *				// Only for request & response messages (non-broadcast) with RESP=1
 *				rs485Message* pResponse;
 *				...Populate the response message...
 *				rs485Respond(pResponse);
 *			}
 *		}
 *		... Do other (non RS485 related) things, but don't get stuck in an infinite loop...
 *	}
 *
 *COPYRIGHT:
 *	(c)2014 by Ron Moerman, All Rights Reserved.
 *
 *	$File: RS485Lib.h $
 *	$Revision: 0.1 $
 *	$IDE: Atmel Studio 6.2 $
 *	$Author: Ron Moerman $
 *	$Email: ron(at)moerman.cc $
 *	$Date: Sunday, September 22, 2014 18:45:22 UTC $
 *==================================================================================================*/

#ifndef __RS485LIB_H__
#define __RS485LIB_H__

/*==================================================================================================*
 *                                    I N C L U D E   H E A D E R S
 *==================================================================================================*/

#include <errorbuf.h>


/*==================================================================================================*
 *                                         C O N S T A N T S
 *==================================================================================================*/

; Registers reserved for the RS485 Library routines
#define STATR R21										//R21 holds the current library TX/RX state.


; RS485 Message parameter length (fixed).
RS485PARAM_LEN = 12										;Message parameter length (fixed).
; Structure of the RS485 message (Request and Response).
RS485MSG_ADDR = 0										;Address byte (Slave or Boardcast address).
RS485MSG_CMD = 1										;Command/Result byte.
RS485MSG_PARAM = 2										;Parameter data buffer address.
RS485MSG_CRC16 = 14										;CRC16 value.
RS485MSG_LEN = 16										;Fixed RS485 message length (16).
; Additional message structure variables to manage transmitting/receiving of the message data.
RS485MSG_IDX = (RS485MSG_CRC16+2)						;Index pointer for next message byte to process.
RS485MSG_CNT = (RS485MSG_IDX+2)							;Count down for message bytes.
RS485MSG_USED = (RS485MSG_CNT+1)						;Indicate if an active message is in the buffer.
#define RS485MSG_SIZE 20								;Total length of RS485 message data structure.

; The 8th address bit indicates whether the Master expects a Response (only valid for non-broadcast).
RESPONSE_EXPECTED = 0x80

; Finite State Machine states.
RS485STATE_INIT = 0										;RS485 not yet initialized.
RS485STATE_REQUEST = 1									;Ready to Transmit/Receive Request or Broadcast.
RS485STATE_COMMAND = 2									;Transmit/Receive the Command byte.
RS485STATE_MSGBODY = 3									;Transmit/receive the message body.
RS485STATE_PROCESS = 4									;Process message received.
RS485STATE_RESPONSE = 5									;Request processed, ready to send Response message.
RS485STATE_UNKNOWN = 7

; The RS485 library error codes.
RS485ERR_OK = 0											;Everything went fine.
RS485ERR_NO_REQUEST_EXPECTED = 1						;Asked for a request but we are in the middle of something.
RS485ERR_BROADCAST_NO_RESPONSE = 2						;Broadcast cannot ask for a response.
RS485ERR_ADDRESS_INVALID = 3							;Address must be >0 and <128.
RS485ERR_NO_RESPONSE_EXPECTED = 4						;Tried to send message to master without being asked.
RS485ERR_INVALID_PARAM_SIZE = 5							;Parameter length invalid (not currently used).
RS485ERR_INVALID_STATE_RECEIVING = 6					;State machine confused somehow when reading.
RS485ERR_NO_REQUEST_AVAILABLE = 7						;Tried to read request but no message was received.
RS485ERR_INVALID_STATE_SENDING = 8						;State machine confused somehow when sending.
RS485ERR_REQUEST_DROPPED = 9							;Message not consumed yet, subsequent messages are dropped.
RS485ERR_INVALID_CRC = 10								;Invalid CRC16 value in message.
RS485ERR_FRAME_ERROR = 11								;Receive frame error.
RS485ERR_STATE_MACHINE_RESET = 255						;Out of sync, state is reset.

#endif