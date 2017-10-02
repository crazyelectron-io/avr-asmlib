/*==================================================================================================*;
;*SYNOPSIS:																							*;
;*	Atmel AVR Library with RS485 generic Master/Slave functions and specific Slave communication	*;
;*	functions.																						*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	20141130 v0.2	Removed SFR_OFFSET fix.															*;
;*	20141108 v0.1	Initial test version.															*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Routines for RS485 Slave devices using hardware based USART of AVR 8-bit MCU's.					*;
;*	Implements a simple RS485-based communications protocol. For more details see the include file	*;
;*	"rs485slave.h".																					*;
;*																									*;
;*NOTES:																							*;
;*	1. It is assumed that all generic initialization, like stackpointer setup is done by the		*;
;*		calling program.																			*;
;*	2.	This library defines two interrupt vectors (TXC and RXC); all other vectors are up to the	*;
;*		calling program.																			*;
;*	3.	Register 21 is used exclusively by the RS485 library routines to permanently hold the		*;
;*		current state and should not be used elsewhere.												*;
;*																									*;
;*COPYRIGHT:																						*;
;*	(c)2014 by Ron Moerman, All Rights Reserved.													*;
;*																									*;
;*	This program comes with ABSOLUTELY NO WARRANTY.													*;
;*	This is free software, and you are welcome to redistribute it under certain conditions.			*;
;*	The program and its source code are published under the GNU General Public License (GPL).		*;
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.										*;
;*																									*;
;*	$File: rs485lib.S $																				*;
;*	$Revision: 0.2 $																				*;
;*	$ASM: AVR-GCC AS $																				*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Tuesday, November 30, 2014 20:34:59 UTC $												*;
;*==================================================================================================*/

/*==================================================================================================*;
;*                                   I N C L U D E   H E A D E R S                                  *;
;*==================================================================================================*/

//#define __SFR_OFFSET 0
		.nolist
#include <avr/io.h>
#include <avr_macros.h>
		.list
#include <errorbuf.h>
#include <rs485lib.h>


;*==================================================================================================*;
;*                          D E V I C E   D E P E N D E N T   D E F I N E S                         *;
;*==================================================================================================*;
//--- The makefile should define F_CPU and BAUD; default is 8 MHz and 38.400.
#ifndef F_CPU
	#warning "F_CPU not defined; assuming 8 MHz."
	#define F_CPU 8000000
#endif
#ifndef BAUD
	#warning "BAUD not defined; assuming 38.400 Baud."
	#define BAUD 38400									//Highest possible baud rate @8MHz w/o external crystal.
#endif
#include <util/setbaud.h>								//Calculates UBRR/USE_2X according to given F_CPU and BAUD.

//--- The makefile should define the pin definitions for controlling RS-485 transceiver direction.
#if defined(__AVR_ATtiny2313__) || defined(__AVR_ATtiny2313A__)
	#ifndef RS485_DIR_PORT
		#warning "RS485_DIR_PORT not defined; assuming PORTD"
		#define RS485_DIR_PORT PORTD
	#endif
	#ifndef RS485_DIR_DDR
		#warning "RS485_DIR_DDR not defined; assuming DDRD"
		#define RS485_DIR_DDR DDRD
	#endif
	#ifndef RS485_DIR_DDPIN
		#warning "RS485_DIR_DDPIN not defined; assuming DDD3"
		#define RS485_DIR_DDPIN DDD3
	#endif
	#ifndef RS485_DIR_PIN
		#warning "RS485_DIR_PIN not defined; assuming PD3"
		#define RS485_DIR_PIN PD3
	#endif
#endif

//--- USART registers and ISR's for RS485 communication.
#if defined(__AVR_ATtiny2313__)||defined(__AVR_ATtiny2313A__)||defined(__AVR_ATtiny4313__)
	#define	RS485_UBRRH UBRRH
	#define RS485_UBRRL UBRRL
	#define RS485_U2X U2X
	#define RS485_UCSRA UCSRA
	#define RS485_UCSRB UCSRB
	#define RS485_UCSRC UCSRC
	#define RS485_TXEN TXEN
	#define RS485_RXEN RXEN
	#undef RS485_URSEL									//Only needed for ATmega8 and similar MCUs.
	#define RS485_UCSZ2 UCSZ2
	#define RS485_UCSZ1 UCSZ1
	#define RS485_UCSZ0 UCSZ0
	#define RS485_UPM0 UPM0
	#define RS485_UPM1 UPM1
	#define RS485_USBS USBS
	#define RS485_UDRE UDRE
	#define RS485_UDR UDR
	#define RS485_MPCM MPCM
	#define RS485_TXC TXC
	#define RS485_RXC RXC
	#define RS485_RXCIE RXCIE
	#define RS485_TXCIE TXCIE
	#define RS485_TXB8 TXB8
	#define RS485_RXB8 RXB8
	#define RS485_FE FE
	#define RS485_DOR DOR
	#define RS485_UPE UPE
	#define RS485_RX_ISR_VECT USART0_RX_vect
	#define RS485_TX_ISR_VECT USART0_TX_vect
#else
	#error "Only ATtiny2313/ATtiny2313A/ATtiny4313 supported (for now)."
#endif


/*==================================================================================================*;
;*                                L I N K E R   D E F I N I T I O N S                               *;
;*==================================================================================================*/

//--- Interrupt routines.
		.global RS485_TX_ISR_VECT						;TX Complete interrupt routine entrypoint.
		.global RS485_RX_ISR_VECT						;RX Complete interrupt routine entrypoint.

//--- Make these library funtions externally accessible.
		.global RS485_message_init
		.global RS485_message_flush
		.global	RS485_set_direction
		.global	RS485_init
		.global RS485_busy
		.global RS485_message_available
		.global RS485_send_message
		.global	RS485_consume
		.global RS485_response_expected


/*==================================================================================================*;
;*                           L I B R A R Y   L O C A L   V A R I A B L E S                          *;
;*==================================================================================================*/
		.section .data

rs485_addr:
		.byte	0										;Our address (or 0 if Master Mode).
//--- Request/Response messages.
rxp:	.byte	0										;Address of receive message buffer.
#if (RAMEND > 256)
		.byte	0
#endif
txp:	.byte	0										;Address of transmit message buffer.
#if (RAMEND > 256)
		.byte	0
#endif


/*==================================================================================================*;
;*                                I N T E R R U P T   R O U T I N E S                               *;
;*==================================================================================================*/
		.section .text

/*--------------------------------------------------------------------------------------------------*;
;* RS485_TX_ISR_VECT: ISR triggered on Transmit Complete (TXC flag) of USART.						*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	ISR triggered on Transmit Complete (TXC flag) of USART to send the entire message byte by byte	*;
;*	until all 16 message bytes are transmitted.														*;
;*	The process is initiated by sending the address byte of the message (containing either a slave	*;
;*	address or the broadcast address).																*;
;*																									*;
;*INPUT:																							*;
;*	None.																							*;
;*																									*;
;*OUTPUT:																							*;
;*	None.																							*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R0 (SREG), R21 (STATR).																			*;
;*																									*;
;*LOCAL STACK USAGE:																				*;
;*	8 bytes (+ rs485_set_status rountine).															*;
;*																									*;
;*NOTES:																							*;
;*	1.	Any error that occurs is added to the error buffer.											*;
;*	2.	STATR is holding the current/new state; Y is pointing at the message being sent; R0 is used	*;
;*		to save the status register during interrupt; R16 is used as a local working register.		*;
;*	3. The happy flow consumes 40-50 CPU cycles, including calling and returning to/from the ISR.	*;
;*--------------------------------------------------------------------------------------------------*/
RS485_TX_ISR_VECT:
		cbi		IO_ADDR(RS485_UCSRB),RS485_TXCIE			;Temporarily disable interrupts on transmit. (2)
		in		R0,IO_ADDR(SREG)						;Get SREG in our status save register. (1)
		PUSHM	R16,YL,ZL								;Save the registers used in this ISR. (6/10)
#if (RAMEND > 256)
		PUSHM	YH,ZH
#endif
; Set up locally used registers.
		lds		YL,txp									;Y points at Response message structure. (2/4)
#if (RAMEND > 256)
		lds		YH,txp+1
#endif
;
; Are we supposed to send the Command or Result byte?
		sbrs	STATR,RS485STATE_COMMAND				;Check if ready to send Command/Result byte. (1/2)
		rjmp	rs485tx_isr_state2						;Skip if not. (2)
; If so, disable MPM mode and send Result byte to UART.
		cbi		IO_ADDR(RS485_UCSRB),RS485_TXB8			;Clear address frame bit. (2)
		ldd		R16,Y+RS485MSG_CMD						;Get Command/Result byte from message. (2)
		out		IO_ADDR(RS485_UDR),R16					;Send Command/Result byte to UART. (1)
		lsl		STATR									;Update our state to send message body. (1)
		rjmp	rs485tx_isr_end							;Done sending the Command/Result byte. (2)
;
; Are we supposed to send the message body?
rs485tx_isr_state2:
		sbrs	STATR,RS485STATE_MSGBODY				;Check if ready to send message body. (1/2)
		rjmp	rs485tx_isr_state3						;Skip if not. (2)
; If so, send the next message byte.
		ldd		ZL,Y+RS485MSG_IDX						;Z points at current message index. (2/4)
#if (RAMEND > 256)
		ldd		ZH,Y+RS485MSG_IDX+1
#endif
		ld		R16,Z+									;Get message byte and update index. (2)
		out		IO_ADDR(RS485_UDR),R16					;Send message byte to UART. (1)
; Check if we must send more message bytes.
		ldd		R16,Y+RS485MSG_CNT						;Get message body size count down in TXR. (2)
		dec		R16										;Count a transmitted message byte. (1)
		breq	_rs485tx_isr_done						;Skip if all bytes transmitted. (1/2)
		std		Y+RS485MSG_CNT,R16						;Save updated message body count down. (2)
		std		Y+RS485MSG_IDX,ZL						;Save updated buffer pointer. (2/4)
#if (RAMEND > 256)
		std		Y+RS485MSG_IDX,ZH
#endif
		rjmp	rs485tx_isr_end							;Go transmit next message byte. (2)
; All message bytes transmitted.
_rs485tx_isr_done:
		lsl		STATR									;Set library state to STATE_PROCESS. (1)
		rjmp	rs485tx_isr_end							;We're done with the message body. (2)
;
; We are done sending the message.
; We receive this interrupt after the last message byte is transmitted.
rs485tx_isr_state3:
		ldi		STATR,(1<<RS485STATE_REQUEST)			;Presume we are going to switch to REQUEST MSG mode. (1)
		cbi		IO_ADDR(RS485_DIR_PORT),RS485_DIR_PIN	;Also preset RS485 transceiver to receive mode. (2)
; Check if we are in master or slave mode.
		lds		R16,rs485_addr							;Get our RS485 bus address. (2)
		tst		R16										;Are we in RS485 Master mode? (1)
		brne	rs485tx_isr_end							;   If not, we're done. (1/2)
; We're in Master mode, check if we did send a message with response required from Slave.
		ldd		R16,Y+RS485MSG_ADDR						;Get the address byte from the message sent. (2)
		sbrc	R16,7									;Response message requested? (1/3)
		rjmp	rs485tx_isr_end							;  If so, we're done.
		sbi		IO_ADDR(RS485_DIR_PORT),RS485_DIR_PIN	;  Else, switch RS485 transceiver to transmit mode, (2)
		ldi		STATR,(1<<RS485STATE_RESPONSE)			;  and set State to Response Requested. (1)
; Restore status and return from interrupt.
rs485tx_isr_end:
		sbi		IO_ADDR(RS485_UCSRB),RS485_TXCIE		;Allow interrupts on transmit again. (2)
#if (RAMEND > 256)
		POPM	YH,ZH									;Restore the used registers. (6/10)
#endif
		POPM	R16,YL,ZL
		out		IO_ADDR(SREG),R0									;Restore SREG and return from interrupt. (5)
		reti


/*--------------------------------------------------------------------------------------------------*;
;* RS485_RX_ISR_VECT: ISR triggered on Receive Complete (RXC flag) of USART.						*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	ISR triggered on Receive Complete (RXC flag) of USART to receive the entire message byte by 	*;
;*	byte until all 16 bytes (including CRC16) are received.											*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R0 (SREG), RXR (dedicated to this ISR).															*;
;*																									*;
;*STACK USAGE:																						*;
;*	9-12 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1.	R0 is dedicated to status register (SREG) save within any ISR.								*;
;*	2.	Any error that occurs is added to the error queue.											*;
;*	3.	R24 is holding the byte received; Y is pointing at the receive data structure; STATR holds	*;
;*		the current/new state; R16 is used as local working register; R0 is used to save the status	*;
;*		register during the interrupt.																*;
;*--------------------------------------------------------------------------------------------------*/
RS485_RX_ISR_VECT:
		in		R0,IO_ADDR(SREG)						;Get SREG in our status save register. (1)
		PUSHM	R16,YL,ZL								;Save the registers used in this ISR. (6/10)
#if (RAMEND > 256)
		PUSHM	YH,ZH
#endif
; Set up locally used registers.
		lds		YL,rxp									;Y points at receive message structure. (4)
#if (RAMEND > 256)
		lds		YH,rxp+1
#endif
;
; If the 9th bit of the address byte is set and we are not still processing the previous message
;	(STATE_PROCESS) the state is forced to STATE_REQUEST to ensure we always have a defined
;	state in case of transmit/receive errors. If the state is STATE_PROCESS, we ignore the message.
		sbrc	STATR,RS485STATE_REQUEST				;Are we expecting an address byte? (1/2)
		rjmp	_rs485rx_isr_in							;  Yes, continue. (2)
		sbis	IO_ADDR(RS485_UCSRB),RS485_RXB8			;If no unsollicited address byte, (2/3)
		rjmp	_rs485rx_isr_in							;  continue. (2)
; Unsollicited address byte received; are we still processing the previous message?
		sbrs	STATR,RS485STATE_PROCESS				;Currently processing a message? (1/2)
		rjmp	_rs485rx_isr_rst						;  If not, go reset state. (2)
; Simply ignore new messages until previous message is processed.
		in		R16,IO_ADDR(RS485_UDR)					;Flush the UART receive buffer, (1)
		rjmp	_rs485rx_isr_end						;  and go wait for next message. (2)
; Fix the state, as we received an address byte and were not expecting it.
_rs485rx_isr_rst:
		ldi		STATR,(1<<RS485STATE_REQUEST)			;Reset state to REQUEST. (2)
		push	R24										;Save parameter register. (2)
		ldi		R24,RS485ERR_STATE_MACHINE_RESET		;Let'm know we fixed the state. (1)
_rs485rx_isr_fe:
		rcall	error_push								;Report the error.
		rcall	RS485_message_flush						;Flush the receive buffer.
		pop		R24										;Restore parameter register. (2)
		sbrs	STATR,RS485STATE_REQUEST				;Are we waiting for an Address byte? (1/2)
		rjmp	_rs485rx_isr_ignore						;  If not, ignore rest of message. (2)
; Read the receive status to check for receive errors.
_rs485rx_isr_in:
		in		R16,IO_ADDR(RS485_UCSRA)				;Get possible receive error status bits.
		andi	R16,(1<<RS485_FE)|(1<<RS485_DOR)|(1<<RS485_UPE)
		breq	_rs485rx_isr_data						;Skip if ok. (1/2)
		push	R24										;Save parameter register. (2)
		ldi		R24,RS485ERR_FRAME_ERROR
		rjmp	_rs485rx_isr_fe							;Go report Frame Error. (2)
; Read the data byte from the UART receive buffer.
_rs485rx_isr_data:
		in		R16,IO_ADDR(RS485_UDR)					;Get the data byte from the UART buffer. (1)
;
; Are we expecting the address byte?
		sbrs	STATR,RS485STATE_REQUEST				;Check current state. (1/2)
		rjmp	_rs485rx_isr_state2						;SKip if not REQUEST state. (2)
		std		Y+RS485MSG_ADDR,R16						;Save received address in message buffer. (2)
		andi	R16,~RESPONSE_EXPECTED					;Mask response bit. (1)
; Check for broadcast message.
		tst		R16										;Is it the broadcast address?. (1)
		breq	_rs485rx_isr_addr						;  Continue receiving if broadcast. (1/2)
; Is this request message addressed at us?
		lds		ZL,rs485_addr
		tst		ZL										;If in Master mode, always accept response messages. (1)
		breq	_rs485rx_isr_addr
		cpse	R16,ZL									;Is this message adressed at us? (1/2)
		rjmp	_rs485rx_isr_end						;  If not for us, go wait for our address. (2)
; It is addressed at us (or a broadcast message). Save address byte in message buffer,
;	turn off MPM mode and go on to receive next byte (the Command/Result byte).
_rs485rx_isr_addr:
		ldi		R16,(0>>MPCM)|(0<<RS485_U2X)			;Multi-processor mode off - can't use CBI/SBI for MCPM flag. (2)
		out		IO_ADDR(RS485_UCSRA),R16
		std		Y+RS485MSG_USED,STATR					;Set message buffer in use flag. (2)
		lsl		STATR									;Next state: receive Command/Result byte. (1)
		rjmp	_rs485rx_isr_end						;We're done with this received byte. (2)
;
; Check for Command byte.
_rs485rx_isr_state2:
		sbrs	STATR,RS485STATE_COMMAND				;Check current state. (1/2)
		rjmp	_rs485rx_isr_state3						;Skip if not expecting Command/Result byte. (2)
		std		Y+RS485MSG_CMD,R16						;Save Command/Result byte in message. (2)
		lsl		STATR									;Next state: receive message body. (1)
		rjmp	_rs485rx_isr_end						;We're done with this received byte. (2)
;
; Check for (next) message body byte.
_rs485rx_isr_state3:
		sbrs	STATR,RS485STATE_MSGBODY				;Check current state. (1/2)
		rjmp	_rs485rx_isr_state4						;Skip if not expecting message body. (2)
; Store message byte in receive buffer.
		ldd		ZL,Y+RS485MSG_IDX						;Z points at current message buffer index. (2/4)
#if (RAMEND > 256)
		ldd		ZH,Y+RS485MSG_IDX+1
#endif
		st		Z+,R16									;Store message byte in buffer. (2)
; Check if we expect more message bytes.
		ldd		R16,Y+RS485MSG_CNT						;Get message body count down. (2)
		dec		R16										;Count a received message byte. (1)
		breq	1f										;Skip if all message bytes received. (1/2)
		std		Y+RS485MSG_CNT,R16						;Save updated message body count down. (2)
		std		Y+RS485MSG_IDX,ZL						;Save updated buffer pointer. (2)
#if (RAMEND > 256)
		std		Y+RS485MSG_IDX,ZH
#endif
		rjmp	_rs485rx_isr_end						;Go receive next byte of message body. (2)
; Done receiving message body.
1:		lsl		STATR									;Set state to PROCESS. (1)
		cbi		IO_ADDR(RS485_UCSRB),RS485_RXCIE		;Ignore messages until this one is processed. (2)
		rjmp	_rs485rx_isr_end						;We're done with the message body. (2)
;
; Invalid state. Flush the message, reset state to REQUEST and report an error.
_rs485rx_isr_state4:
		push	R24										;Save parameter register. (2)
		rcall	RS485_message_flush						;Ignore the received bytes.
		ldi		R24,RS485ERR_INVALID_STATE_RECEIVING	;Let'm know we reset the state. (1)
		rcall	error_push								;Push the error code in the error queue.
		pop		R24										;Restore parameter register. (2)
_rs485rx_isr_ignore:
		ldi		STATR,(1<<RS485STATE_REQUEST)			;Reset state to new request. (2)
		ldi		R16,(1<<RS485_MPCM)						;Multi-processor mode on (for address). (2)
		out		IO_ADDR(RS485_UCSRA),R16
; Return from RXC interrupt.
_rs485rx_isr_end:
#if (RAMEND > 256)
		POPM	YH,ZH									;Restore the used registers. (6/10)
#endif
		POPM	R16,YL,ZL
		out		IO_ADDR(SREG),R0						;Restore SREG and return from RXC interrupt.
		reti


/*==================================================================================================*;
;*                       L O C A L   M A S T E R / S L A V E   R O U T I N E S						*;
;*==================================================================================================*/

/*--------------------------------------------------------------------------------------------------*;
;* rs485_calc_crc: Calculate the CRC for the passed message.										*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Calculate the CRC for the passed message.														*;
;*	Algorithm: CRC-16-CCITT, x16 + x12 + x5 + 1, 0x1021 / 0x8408 / 0x8810.							*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	Z = Address of message buffer.																	*;
;*																									*;
;*OUTPUT:																							*;
;*	R18:R19 = Calculated CRC value (LO:HI).															*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R18,R19,R24.																					*;
;*																									*;
;*STACK USAGE:																						*;
;	7 bytes (including call to this routine and called routines).									*;
;*																									*;
;*NOTES:																							*;
;*	1. This routine uses 398 CPU cycles (27/byte), including return to calling routine.				*;
;*--------------------------------------------------------------------------------------------------*/
		.func	rs485_calc_crc
rs485_calc_crc:
		PUSHM	R16,R25,ZL								;Save used registers. (6/8)
#if (RAMEND > 256)
		push	ZH
#endif
		ser		R18										;Set initial CRC value to 0xFFFF. (2)
		ser		R19
		ldi		R16,RS485MSG_LEN-2						;All message bytes, except CRC16 bytes. (1)
; Loop through all message bytes.
_crc_loop:
		ld		R24,Z+									;Get byte to add to calculation. (2)
; Update the the CRC16 value with current message byte.
		SWAPR	R18,R19									;Start by swapping the CRC16 bytes. (3)
		eor		R18,R24									;First XOR. (1)
		mov		R25,R18									;Second XOR. (1)
		swap	R25										;These 2 instructions are faster than 4x"lsr 4". (3)
		andi	R25,0x0F
		eor		R18,R25
		mov		R25,R18									;Third XOR. (1)
		swap	R25
		andi	R25,0xF0
		eor		R19,R25
		mov		R25,R18									;Fourth XOR. (1)
		swap	R25
		mov		R24,R25
		andi	R25,0xF0
		andi	R24,0x0F
		lsl		R25
		rol		R24
		eor		R18,R25
		eor		R19,R24
; Check if at end of message data.
		dec		R16										;Count a processed message byte. (1)
		brne	_crc_loop								;Loop until all message bytes done. (1/2)
; Done calcuating CRC16.
#if (RAMEND > 256)
		pop		ZH										;Restore used registers and return. (10/12)
#endif
		POPM	R16,R25,ZL
		ret
		.endfunc


/*==================================================================================================*;
;*                      C O M M O N   M A S T E R / S L A V E   R O U T I N E S						*;
;*==================================================================================================*/

/*--------------------------------------------------------------------------------------------------*;
;* RS485_set_direction: Set system in either Receive or Transmit mode.								*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	This routine set the UART, Interrupt flags and RS485 transceiver to either Transmit mode or		*;
;*	Receive mode, specified by input parameter register R24.										*;
;*	If R24 == 0, we switch to Transmit Mode, and if R24 !=0 we switch to Receive Mode.				*;
;*																									*;
;*INPUT:																							*;
;*	R24 = Transmit (0) or Receive Mode (!0).														*;
;*																									*;
;*OUTPUT:																							*;
;*	None.																							*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	None.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	?? bytes (including calling this routine).														*;
;*																									*;
;*NOTES:																							*;
;*	1. The ZEROR is assumed to be initialized with zero (0).										*;
;*	2. This routine counts 10-21 CPU cycles, including returning to calling routine.				*;
;*	3.	The State (STATR) is not changed by this routine; that's up to the caller.					*;
;*--------------------------------------------------------------------------------------------------*/
		.func	RS485_set_direction
RS485_set_direction:
		tst		R24										;Switch to Transmit Mode? (1)
		breq	_rs485_mode_tx							;  If so, skip. (1/2)
; Switch system to Receive Mode.
		cbi		IO_ADDR(RS485_DIR_PORT),RS485_DIR_PIN	;Set RS485 transceiver in Receive mode. (2)
		sbi		IO_ADDR(RS485_UCSRB),RS485_RXCIE		;Allow interrupts on Receive. (2)
		ret												;Done. (4)
; Switch to Transmit Mode.
_rs485_mode_tx:
		sbi		IO_ADDR(RS485_DIR_PORT),RS485_DIR_PIN	;Set RS485 transceiver in Transmit mode. (2)
_rs485_mode_flush:
		sbis	IO_ADDR(RS485_UCSRA),RS485_RXC			;Receive complete flag set? (1/2)
		rjmp	1f										;  If not. we're done. (2)
		in		R24,IO_ADDR(RS485_UDR)					;Else, empty UART Data Register. (1)
		rjmp	_rs485_mode_flush						;  And keep flushing until UART buffer empty. (2)
1:		sbi		IO_ADDR(RS485_UCSRB),RS485_TXCIE		;Allow interrupts on Transmit. (2)
		ret												;Done (4)
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_message_init: Prepare an RS485 message structure for transmit/receive.						*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Initialize the static/control variables in the RS485 message buffer, but don't touch the		*;
;*	message body. The message size is fixed at 16 bytes.											*;
;*																									*;
;*INPUT:																							*;
;*	Z = Address of RS485 message to initialize;														*;
;*	R24 = Slave or Broadcast address to store in message.											*;
;*																									*;
;*OUTPUT:																							*;
;*	Z = address of initialized RS485 message;														*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	4 bytes (including calling this routine).														*;
;*																									*;
;*NOTES:																							*;
;*	1. The ZEROR is assumed to be initialized with zero (0).										*;
;*	2. This routine counts 25-34 CPU cycles, including returning to calling routine.				*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_message_init
RS485_message_init:
		PUSHM	YL,ZL									;Save used registers. (4/8)
#if (RAMEND > 256)
		PUSHM	YH,ZH
#endif
; Save the passed Slave or Broadcast address in the message.
		std		Z+RS485MSG_ADDR,R24						;Set Address byte in message. (2)
; Initialize the message index and counter.
#if (RAMEND > 256)
		movw	YL,ZL									;Point Y at message body. (3)
		adiw	YL,RS485MSG_PARAM
#else
		mov		YL,ZL
		subi	YL,-RS485MSG_PARAM						;  Small RAM version of it. (2)
#endif
		std		Z+RS485MSG_IDX,YL						;Set message index @ start of message body. (2/4)
#if (RAMEND > 256)
		std		Z+RS485MSG_IDX+1,YH
#endif
		ldi		R24,RS485MSG_LEN-RS485MSG_PARAM			;Preset message process counter. (3)
		std		Z+RS485MSG_CNT,R24
		std		Z+RS485MSG_USED,ZEROR					;Zero to Used flag. (2)
; Restore and return.
#if (RAMEND > 256)
		POPM	YH,ZH									;Restore used registers and return. (8/12)
#endif
		POPM	YL,ZL
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_message_flush: Flush and initialize an RS485 message structure (clear all data).			*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Flush the message data and reset the index variables in the message structure. The message size	*;
;*	is currently fixed at 16 bytes.																	*;
;*																									*;
;*INPUT:																							*;
;*	Z = Address of RS485 message to flush.															*;
;*																									*;
;*OUTPUT:																							*;
;*	Z = address of flushed RS485 message;															*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	X bytes (including calling this routine).														*;
;*																									*;
;*NOTES:																							*;
;*	1.	The ZEROR is assumed to be initialized with zero (0).										*;
;*	2.	This routine counts XX CPU cycles, including returning to calling routine.					*;
;*	3.	The UART receive buffer is flushed too.														*;
;*	4.	This routine comsumes xx-xx CPU cycles, including retuning to caller.						*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_message_flush
RS485_message_flush:
; Initialize the message constants and control variables.
		clr		R24										;Use address 0x00 for generic buffer flush. (1)
		rcall	RS485_message_init						;Initialize pointers and counters. (25/34)
		push	ZL										;Save used registers. (2/4)
#if (RAMEND > 256)
		push	ZH
#endif
		std		Z+RS485MSG_CMD,ZEROR					;Clear the Command/Result byte. (2)
; Clear the parameter bytes.
		ldi		R24,RS485PARAM_LEN						;Set count down. (1)
#if (RAMEND > 256)
		adiw	ZL,RS485MSG_PARAM						;Point Z at start of parameters. (2/1)
#else
		subi	ZL,-RS485MSG_PARAM
#endif
1:		st		Z+,ZEROR								;Clear parameter byte. (2)
		dec		R24										;Count down. (1)
		brne	1b										;More to flush? (1/2)
; Preset the CRC16 value with 0xFFFF.
		ser		R24										;Load 0xFF in R24. (1)
		st		Z+,R24									;Put in first CRC byte, (2)
		st		Z,R24									; and in second CRC byte. (2)
; Restore and return.
#if (RAMEND > 256)
		pop		ZH										;Restore used registers and return. (6/8)
#endif
		pop		ZL
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_init: Initialize UART and variables for RS485 Master or Slave mode.						*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Initialize UART and variables for RS485 Master or Slave mode. The message size is fixed at 16	*;
;*	bytes.																							*;
;*	The passed RS485 receive message buffer is flushed and initialized with starting values.		*;
;*	The Frame format is set at 1 start, 9 data bits (MPM mode), no parity, 2 stop bits.				*;
;*	The Baud rate is defined by the BAUD makefile variable.											*;
;*																									*;
;*INPUT:																							*;
;*	Z = Address of RS485 message buffer to use for receiving messages;								*;
;*	R24 = Slave address, or 0x00 if Master mode.													*;
;*																									*;
;*OUTPUT:																							*;
;*	Z = Address of initialized RS485 receive message;												*;
;*	STATR = Rquest message state of RS485 library (STATE_REQUEST).									*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24,R25,STATR.																					*;
;*																									*;
;*STACK USAGE:																						*;
;*	11 bytes (including calling this routine).														*;
;*																									*;
;*NOTES:																							*;
;*	1. The ZEROR register is assumed to be initialized with zero (0x00).							*;
;*	2. This routines consumes xx CPU cycles, including, returning to the caller.					*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_init
RS485_init:
		push	YL										;Save the used registers. (2/4)
#if (RAMEND > 256)
		push	YH
#endif
		ENTERCRITICAL									;No interrupts during initialization. (1)
		sts		rs485_addr,R24							;Save our Slave/Master address. (2)
		sbi		IO_ADDR(RS485_DIR_DDR),RS485_DIR_DDPIN	;Set pin as output to control RS485 buffers. (2)
; Set the baud rate.
		ldi		R25,UBRRH_VALUE							;High byte of Baud rate. 2(
		out		IO_ADDR(RS485_UBRRH),R25
		ldi		R25,UBRRL_VALUE							;Low byte of Baud rate. (2)
		out		IO_ADDR(RS485_UBRRL),R25
; Set Multiprocessor Mode (only applicable to Slave), clear TXC flag and disable 2X mode.
		ldi		R25,(1<<RS485_TXC)|(0<<RS485_U2X)|(1<<RS485_MPCM)
		out		IO_ADDR(RS485_UCSRA),R25
; UART TX/RX on: send/receive, both trigger interrupts on completion.
		ldi		R25,(1<<RS485_TXEN)|(1<<RS485_RXEN)|(1<<RS485_RXCIE)|(1<<RS485_TXCIE)|(1<<RS485_UCSZ2)|(0<<RS485_TXB8)
		out		IO_ADDR(RS485_UCSRB),R25
; Set Frame to 1 Start bit ('0'), 9 data bits, Odd Parity and 2 Stop bits ('1').
		ldi		R25,(1<<RS485_UPM1)|(1<<RS485_UPM0)|(1<<RS485_UCSZ1)|(1<<RS485_UCSZ0)|(1<<RS485_USBS)
		out		IO_ADDR(RS485_UCSRC),R25
; Initialize the RS485 receive message buffer @Z (used in the RX ISR).
		sts		rxp,ZL									;Save Receive message buffer address. (4)
#if (RAMEND > 256)
		sts		rxp+1,ZH
#endif
		rcall	RS485_set_direction						;Set TX/RX mode according to Master/Slave mode.
		rcall	RS485_message_flush						;Initialize the receive message buffer.
		rcall	error_init								;Initialize the error queue.
		ldi		STATR,(1<<RS485STATE_REQUEST)			;Set initial state to 'Request Message'.
		EXITCRITICAL									;Restore interrupt state.
#if (RAMEND > 256)
		pop		YH										;Restore saved registers and return. (6/8)
#endif
		pop		YL
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_busy: Check if RS485 interface is busy transmitting or receiving.							*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if RS485 interface is busy transmitting or receiving.										*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	None.																							*;
;*																									*;
;*OUTPUT REGISTERS:																					*;
;*	CF=0:	No transmit or receive busy;															*;
;*	CF=1:	A transmit or receive is currently busy.												*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;	2 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1. This routine uses 9-12 CPU cycles, including returning to calling routine.					*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_busy
RS485_busy:
		clc
		sbrc	STATR,RS485STATE_REQUEST				;Are we ready to start request? (1)
		rjmp	1f										; If so, exit with CF=0. (1/2)
		sbrs	STATR,RS485STATE_RESPONSE				;Are we ready to start response? (1)
		rjmp	2f										; If not, exit with CF=1. (1/2)
; Status is ok, additionally check UART transmit buffer.
1:		sbis	IO_ADDR(RS485_UCSRA),RS485_UDRE			;UART transmit buffer emtpy? (1/2)
2:		sec												;Otherwise, set Carry flag. (1)
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_message_available: Check if a received message is waiting to be processed.					*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if a received message is waiting to be processed.											*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	None.																							*;
;*																									*;
;*OUTPUT REGISTERS:																					*;
;*	CF=0: No message available;																		*;
;*	CF=1: message waiting to be processed.															*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	None.																							*;
;*																									*;
;*STACK USAGE:																						*;
;	2 bytes (for return adddress).																	*;
;*																									*;
;*NOTES:																							*;
;*	1. This routine uses 9 CPU cycles, including returning to the calling routine.					*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_message_available
RS485_message_available:
		sbi		IO_ADDR(RS485_UCSRB),RS485_RXCIE		;Ready to receive messages. (2)
		sec												;CF=1 means a message is waiting. (1)
		sbrs	STATR,RS485STATE_PROCESS				;Ready to process a message? (1/2)
		clc												;Return CF=0 if no message waiting. (1)
		ret												;Done. (4)
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_consume: Get the received message to process.												*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Get the received message to process.															*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	None.																							*;
;*																									*;
;*OUTPUT REGISTERS:																					*;
;*	CF=0: OK, message to process @Z;																*;
;*	CF=1: Error.																					*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24,Z.																							*;
;*																									*;
;*STACK USAGE:																						*;
;	10 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1.	The calling program should have called rs485_message_available to check if a message is		*;
;*		available to consume.																		*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_consume
RS485_consume:
; Check the CRC16 value.
		lds		ZL,rxp									;Z points at received message. (2/4)
#if (RAMEND > 256)
		lds		ZH,rxp+1
#endif
		PUSHM	R18,R19									;Save used registers. (4)
		rcall	rs485_calc_crc							;Calculate the CRC16 of this message.
		ldd		R24,Z+RS485MSG_CRC16+1
		cp		R19,R24									;CRC16 is the same as in message buffer? (1)
		brne	1f
		ldd		R24,Z+RS485MSG_CRC16
		cp		R18,R24
		POPM	R18,R19									;Restore used registers. (4)
		breq	2f
; Invalid CRC16, return error.
1:		ldi		R24,RS485ERR_INVALID_CRC
		rjmp	error_push
; Return the message (@Z).
2:		lds		R24,rs485_addr
		rcall	RS485_set_direction						;Set TX or RX mode, depending on Slave/Master Mode.
		clc												;Return OK (CF=0). (5)
; Restore and return.
		ret
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_send_message: Send message in the buffer.													*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Send a message to the Master or Slave.															*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	Z = Address of RS485 message to transmit.														*;
;*																									*;
;*OUTPUT REGISTERS:																					*;
;*	None.																							*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;	8 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1. The CRC16 value is calculated and stored in the RS485 message structure.						*;
;*	2. This routine uses XXX-XXX CPU cycles, including returning to calling routine (happy flow).	*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_send_message
RS485_send_message:
; Calculate and store CRC16 value of message.
		PUSHM	R18,R19									;Save registers used to caclulate CRC16. (4)
		rcall	rs485_calc_crc							;Calculate CRC16 value in R18:R19. (400)
		std		Z+RS485MSG_CRC16,R18					;Save CRC16 value in message. (4)
		std		Z+RS485MSG_CRC16+1,R19
		POPM	R18,R19									;Restore used registers. (4)
; Wait until any pending transmit/receive done and UART TX buffer is empty.
1:		rcall	RS485_busy								;Check status. (9-12)
		brcs	1b										;Wait while busy, (1/2)
; Store the message address for use in the transmit ISR.
		sts		txp,ZL									;Store message to send in txp variable for ISR. (2)
#if (RAMEND > 256)
		sts		txp+1,ZH
#endif
		clr		R24
		rcall	RS485_set_direction						;Set in Transmit Mode.
; Send the first response byte (ADDRESS); subsequent bytes are sent in the TX ISR.
		sbi		IO_ADDR(RS485_UCSRB),RS485_TXB8			;Set the address frame bit. (2)
		ldd		R24,Z+RS485MSG_ADDR						;Get address byte from message. (2)
		ldi		STATR,(1<<RS485STATE_COMMAND)			;Update status. (1)
		out		IO_ADDR(RS485_UDR),R24					;Send the address byte. (1)
		ret												;Done. (4)
		.endfunc


;*--------------------------------------------------------------------------------------------------*;
;* RS485_response_expected: Check if a Response message is expected.								*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if a Response message is expected. This routine tests if the 8th bit of the slave			*;
;*	address is set in the message buffer.															*;
;*																									*;
;*INPUT REGISTERS:																					*;
;*	Z = Points at message to check.																	*;
;*																									*;
;*OUTPUT REGISTERS:																					*;
;*	CF=0:	No response expected;																	*;
;*	CF=1:	Response expected.																		*;
;*																									*;
;*REGISTERS CHANGED:																				*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;	2 bytes (including rcall to this routine).														*;
;*																									*;
;*NOTES:																							*;
;*	1. This routine uses 9 CPU cycles on ATtiny, including returning to the calling routine.		*;
;*--------------------------------------------------------------------------------------------------*;
		.func	RS485_response_expected
RS485_response_expected:
		ldd		R24,Z+RS485MSG_ADDR						;Get Slave address byte. (2)
		sec												;CF=1 means response bit is set. (1)
		sbrs	R24,7									;Response expected bit set? (1/2)
		clc												;CF=0: no response expected. (1)
		ret
		.endfunc

		.end
