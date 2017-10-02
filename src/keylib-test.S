#define __SFR_OFFSET 0

#include <avr/io.h>
#include <avr_macros.h>
#include <keylib.h>

#define LED_DDR DDRB
#define LED_TOGGLE PINB
#define LED_RED 4
#define LED_GREEN 5
#define LED_YELLOW 6

#define KEY_MASK (1<<KEY0)

		.section .text
		.global main
main:
//--- Intialize LEDs and keys.
		ldi		R16,((1<<LED_RED)|(1<<LED_GREEN)|(1<<LED_YELLOW))	//Mask for all 3 LEDs.
		out		LED_DDR,R16			//Set PD4..PD6 as output.
		ldi		R24,KEY_MASK							//Specify the key(s) we want to use.
		rcall	keys_init								//Setup keys for debounced status read.
//--- Init succeeded, toggle all 3 LEDs.
		out		LED_TOGGLE,R16					//Toggle all 3 LEDs.
		sei												;Enable interrupts.
//--- Main program loop.
loop:	ldi		R24,KEY_MASK							;Specify keys we want to check.
		rcall	keys_short								;Key pressed shortly?
		breq	1f										;Skip if no key short pressed.
		sbi		LED_TOGGLE,LED_RED				//Short pressed: Red LED toggle.
1:		ldi		R24,KEY_MASK							;Specify keys we want to check.
		rcall	keys_long								;Key pressed long?
		breq	2f										;Skip if no key long pressed.
		sbi		LED_TOGGLE,LED_GREEN			//Long pressed: Toggle Green LED.
//--- Single press and repeat.
2:		rjmp	loop

		.end
