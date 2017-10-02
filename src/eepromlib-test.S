//#define __SFR_OFFSET 0

#include <avr/io.h>
#include <avr_macros.h>

#define LED_DDR IO_ADDR(DDRD)
#define LED_PORT IO_ADDR(PORTD)
#define LED_TOGGLE IO_ADDR(PIND)
#define LED_RED PD4
#define LED_GREEN PD5
#define LED_YELLOW PD6

		.section .text
		.global main
		.func	main
main:
; Intialize LEDs.
		ldi		R16,(1<<LED_RED|1<<LED_GREEN|1<<LED_YELLOW)	;Mask for all 3 LEDs.
		out		LED_DDR,R16								;Set PD4..PD6 as output.
		cbi		LED_PORT,LED_RED						;Turn Red LED off.
		cbi		LED_PORT,LED_GREEN						;Turn Green LED off.
		sbi		LED_PORT,LED_YELLOW						;Turn Yellow LED on.
		sei
; Write 10 bytes to EEPROM from address 0x10.
		ldi		XL,0x10								;EEPROM start address to write to.
#if (EEPROMEND > 256)
		clr		XH
#endif
		ldi		ZL,lo8(string)						;Point at test string to write to EEPROM.
#if (RAMEND > 256)
		ldi		ZH,hi8(string)
#endif
		ldi		R25,10								;Write 10 bytes to EEPROM.
1:		lpm		R24,Z								;Get byte from flash memory in R24.
#if (RAMEND > 256)
		adiw	ZL,1								;Update flash memory pointer.
#else
		inc		ZL
#endif
		rcall	ee_write_byte						;Write data to EEPROM
#if (EEPROMEND >256)
		adiw	XL,1								;Update EEPROM address
#else
		inc		XL
#endif
		dec		R25									;Decrement counter.
		brne	1b									;Loop while not done.
; Toggle YELLOW LED to indicate EEPROM action done.
		sbi		LED_TOGGLE,LED_YELLOW				;Toggle Yellow LED.
; Read back the 10 bytes and compare with SRAM string.
		ldi		XL,0x10								;EEPROM start address to read from.
#if (EEPROMEND > 256)
		clr		XH
#endif
		ldi		ZL,lo8(string)						;Point at test string to cmpare with.
#if (RAMEND > 256)
		ldi		ZH,hi8(string)
#endif
;
		ldi		R25,10								;Read 10 bytes from EEPROM.
check1:	rcall	ee_read_byte						;Read data byte to EEPROM.
		lpm											;Read byte from flash.
		cp		R0,R24								;Are they the same?
		brne	ee_error1							;If not, error!
#if (EEPROMEND > 256)
		adiw	XL,1								;Update EEPROM address.
#else
		inc		XL
#endif
#if (RAMEND > 256)
		adiw	ZL,1								;Update compare string address.
#else
		inc		ZL
#endif
		dec		R25									;Decrement counter.
		brne	check1								;Loop while not done.
; Toggle YELLOW LED on to indicate EEPROM read done.
		sbi		LED_TOGGLE,LED_YELLOW
		nop
; Wait a while.
		ldi		R23,20
		ser		R24
		ser		R25
delay:	dec		R25
		brne	delay
		dec		R24
		brne	delay
		dec		R23
		brne	delay
		nop
; Done waiting, read EEPROM again.
; Toggle YELLOW LED on to indicate EEPROM read starting.
		sbi		LED_TOGGLE,LED_YELLOW
		ldi		XL,0x10								;EEPROM start address to read from.
#if (EEPROMEND > 256)
		clr		XH
#endif
		ldi		ZL,lo8(string)						;Point at test string to cmpare with.
#if (RAMEND > 256)
		ldi		ZH,hi8(string)
#endif
		ldi		R25,10								;Read 10 bytes from EEPROM.
check2:	rcall	ee_read_byte						;Read data byte to EEPROM.
		lpm											;Read byte from flash.
		cp		R0,R24								;Are they the same?
		brne	ee_error2							;If not, error!
#if (EEPROMEND > 256)
		adiw	XL,1								;Update EEPROM address.
#else
		inc		XL
#endif
#if (RAMEND > 256)
		adiw	ZL,1								;Update compare string address.
#else
		inc		ZL
#endif
		dec		R25									;Decrement counter.
		brne	check2								;Loop while not done.
; Turn GREEN LED on to indicate done.
		sbi		LED_PORT,LED_GREEN
1:		nop
		nop
		nop
		rjmp	1b
		ret
; Error occured.
ee_error1:
		ldi		R24,0x81
; Turn RED LED on to indicate error.
		sbi		LED_PORT,LED_RED				;Turn RED LED on.
		nop
		ret
ee_error2:
		ldi		R24,0x82
; Turn RED LED on to indicate error.
		sbi		LED_PORT,LED_RED				;Turn RED LED on.
		nop
		ret
		.endfunc

string:
		.byte	0x0F,0xF0,0x02,0x77,0x55,0xAA,0xFF,0x88,0x01,0x00
		.end
