#define __SFR_OFFSET 0

#include <avr/io.h>
#include <avr_macros.h>
#include <errorbuf.h>
#include <keys.h>
#include <rs485lib.h>

#define LED_PORT PORTD
#define LED_DDR DDRD
#define LED_TOGGLE PIND
#define LED_RED PD4
#define LED_GREEN PD5
#define LED_YELLOW PD6

#define KEY_MASK (1<<KEY0)

#define SLAVE_ADDRESS 0x01

		.section .data
slave_addr:
		.byte	0
req:	.space	RS485MSG_SIZE							;Request message buffer.
resp:	.space	RS485MSG_SIZE							;Response message buffer.

		.section .text
		.global main
main:
// Intialize LEDs and keys.
		ldi		R16,(1<<LED_RED|1<<LED_GREEN|1<<LED_YELLOW)
		out		LED_DDR,R16								;Initialize all LED ports.
		ldi		R24,KEY_MASK							;Specify the keys we want to use.
		clr		R25										;No repeat keys.
		rcall	keys_init								;Setup keys for debounced status read.
// Initialize RS485 Library.
		ldi		R24,SLAVE_ADDRESS						;Set Slave address to communicate with.
		sts		slave_addr,R24
		ldi		ZL,lo8(resp)
#if (RAMEND > 256)
		ldi		ZH,hi8(resp)
#endif
		clr		R24										;Set Master address.
		rcall	RS485_init								;Initialize RS485 Library.
		brcc	1f
		rjmp	do_error
// RS485 init succeeded.
1:		nop
// Wait for key press to send Request message.
wait_key:
		sbi		LED_TOGGLE,LED_GREEN					;Toggle GREEN LED to indicate wait for key press.
		cbi		LED_PORT,LED_RED						;RED LED off.
		ldi		R24,KEY_MASK							;Specify keys we want to check.
		clr		R25										;No repeat keys.
		rcall	keys_pressed							;Get key pressed status.
		breq	wait_key								;Loop if no key pressed.
; Key has been pressed, send message.
		cbi		LED_PORT,LED_GREEN						;Key pressed, turn GREEN LED off.
; Create Request message.
		ldi		ZL,lo8(req)								;Get address of request message buffer.
#if (SRAM_START > 256)
		ldi		ZH,hi8(req)
#endif
		rcall	RS485_message_flush						;Initialize the request message.
		lds		R24,slave_addr
		ori		R24,RESPONSE_EXPECTED
		std		Z+RS485MSG_ADDR,R24
		ldi		R24,0x31								;Set Command byte.
		std		Z+RS485MSG_CMD,R24
		ldi		R24,0xF0								;Store 1st parameter byte.
		std		Z+RS485MSG_PARAM,R24
		ldi		R24,0x0F								;Store 2nd parameter byte.
		std		Z+RS485MSG_PARAM+1,R24
		ldi		R24,0xAA								;Store 3rd parameter byte.
		std		Z+RS485MSG_PARAM+2,R24
		ldi		R24,0x11								;Store 4th parameter byte.
		std		Z+RS485MSG_PARAM+3,R24
		ldi		R24,0x22								;Store 5th parameter byte.
		std		Z+RS485MSG_PARAM+4,R24
		ldi		R24,0x33								;Store 6th parameter byte.
		std		Z+RS485MSG_PARAM+5,R24
		ldi		R24,0x44								;Store 7th parameter byte.
		std		Z+RS485MSG_PARAM+6,R24
		ldi		R24,0x55								;Store 8th parameter byte.
		std		Z+RS485MSG_PARAM+7,R24
		ldi		R24,0x66								;Store 9th parameter byte.
		std		Z+RS485MSG_PARAM+8,R24
		ldi		R24,0x77								;Store 10th parameter byte.
		std		Z+RS485MSG_PARAM+9,R24
		ldi		R24,0x88								;Store 11th parameter byte.
		std		Z+RS485MSG_PARAM+10,R24
		clr		R24										;Store 12th parameter byte.
		std		Z+RS485MSG_PARAM+11,R24
; Send Request message when ready.
wait_send:
		rcall	RS485_busy								;RS485 interface still busy?
		brcs	wait_send
		rcall	RS485_send_message						;Send RS485 message.
		brcs	do_error
		sbi		LED_PORT,LED_YELLOW						;YELLOW LED on, indicating send in progress.
		nop
wait_response:
		rcall	RS485_message_available					;Is a RS485 message available?
		brcs	go_consume								;If so, go process it.
		sbi		LED_TOGGLE,LED_YELLOW					;Toggle YELLOW LED to show we are waiting.
		rjmp	wait_response
; Received a Response, process it.
go_consume:
		sbi		LED_PORT,LED_GREEN
		rcall	RS485_consume
		brcs	do_error
		ldd		R16,Z+RS485MSG_CMD
		sbi		LED_PORT,LED_RED						;RED LED on.
		cbi		LED_PORT,LED_GREEN						;GREEN LED off.
		cpi		R16,0xB1								;Response OK?
		brne	wait_done
		cbi		LED_PORT,LED_RED						;RED LED off.
		sbi		LED_PORT,LED_GREEN						;GREEN LED on.
wait_done:
		rcall	RS485_busy								;RS485 interface still busy?
		brcs	wait_done
		sbi		LED_PORT,LED_RED						;Red LED on to indicate message sent.
; Done. Loop.
		nop
key2:
		ldi		R24,KEY_MASK
		clr		R25
		rcall	keys_pressed
		breq	key2
		cbi		LED_PORT,LED_RED						;Red LED off.
		cbi		LED_PORT,LED_YELLOW						;Yellow LED off.
		cbi		LED_PORT,LED_GREEN						;Green LED off.
		rjmp	wait_key
;
; Handle errors.
;
do_error:
		sbi		LED_PORT,LED_RED						;RED LED on.
		sbi		LED_PORT,LED_GREEN						;GREEN LED on.
		sbi		LED_PORT,LED_YELLOW						;YELLOW LED on.
		rcall	error_pop								;Get the error code in R24.
		cbi		LED_PORT,LED_RED						;RED LED off.
		brcc	do_error
		nop
do_stop:
		sleep
		rjmp	do_stop
		nop

		.end
