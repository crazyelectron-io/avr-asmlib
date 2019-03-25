#define __SFR_OFFSET 0

#include <avr/io.h>
#include <avr_macros.h>
#include <errorbuf.h>
#include <rs485lib.h>

// Slave address in EEPROM.
#define EE_SLAVE_ADDR 0x01

; LED Control ports & pins.
#define LED_DDR DDRD
#define LED_PORT PORTD
#define LED_TOGGLE PIND
#define LED_RED PD4
#define LED_GREEN PD5
#define LED_YELLOW PD6


		.section .eeprom
ee_slave_addr:
		.byte	0x01									;Address slave listens on.


		.section .data
req:	.space	RS485MSG_SIZE							;Request message buffer.
resp:	.space	RS485MSG_SIZE							;Response message buffer.
addr:	.byte 0

		.section .text
		.global main
main:
// Initialize LEDS.
		ldi		R16,(1<<LED_RED|1<<LED_GREEN|1<<LED_YELLOW)	;Mask for all 3 LEDs.
		out		LED_DDR,R16								;Set PD4..PD6 as output with all LEDs off.
; Read Slave address from EEPROM.
		ldi		XL,lo8(ee_slave_addr)
#if (EEPROMEND > 256)
		ldi		XH,hi8(ee_slave_addr)
#endif
		rcall	ee_read_byte
		sts		addr,R24
// Initialize RS485 Library.
		ldi		ZL,lo8(req)
#if (RAMEND > 256)
		ldi		ZH,hi8(req)
#endif
		rcall	RS485_init
		brcs	do_error
		nop
; RS485 init succeeded, turn green LED on.
2:		sbi		LED_PORT,LED_GREEN
		nop
; Wait for a Request message.
loop:	rcall	RS485_message_available
		brcs	go_consume
		sbi		LED_TOGGLE,LED_GREEN					;Toggle GREEN LED to show we are waiting.
		rjmp	loop
		nop
; Received a Request, process it.
go_consume:
		rcall	RS485_consume
		brcs	do_error
		ldd		R16,Z+RS485MSG_CMD
		cpi		R16,0x31								;Command to turn LED on (ASCII '1')?
		brne	4f
		sbi		LED_PORT,LED_YELLOW
		rjmp	5f
4:		cbi		LED_PORT,LED_YELLOW
5:		nop
; Check if a Response is required.
		rcall	RS485_response_expected
		brcc	no_response								;Skip if no response requested.
; Create a Response message.
		movw	YL,ZL									;Save request message pointer in Y.
		ldi		ZL,lo8(resp)							;Get address of response message buffer.
#if (RAMEND > 256)
		ldi		ZH,hi8(resp)
#endif
		rcall	RS485_message_flush						;Initialize the response message.
		lds		R24,addr
		std		Z+RS485MSG_ADDR,R24						;Set our address in message.
		ldi		R24,0xB1								;Return result byte.
		std		Z+RS485MSG_CMD,R24
		ldi		R24,0x01								;Store first parameter byte.
		std		Z+RS485MSG_PARAM,R24
		ldi		R24,0x02								;Store second parameter byte.
		std		Z+RS485MSG_PARAM+1,R24
		ldi		STATR,RS485STATE_RESPONSE
; Send Reponse message when ready.
wait_send:
		rcall	RS485_busy
		brcs	wait_send
		rcall	RS485_send_message
		brcs	do_error
		nop
; Done. Loop.
no_response:
		ldi		STATR,RS485STATE_REQUEST
		nop
		nop
		rjmp	loop
;
; Handle errors.
;
do_error:
		rcall	error_pop
		sbi		LED_PORT,LED_RED
		sbi		LED_PORT,LED_GREEN
		sbi		LED_PORT,LED_YELLOW
		brcc	do_error
do_stop:
		sleep
		rjmp	do_stop

		.end
