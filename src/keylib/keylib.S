/*======================================================================================
 *SYNOPSIS:
 *	Key de-bouncing and status library routines with repeat detection for 8-bit AVR MCUs
 *  and up to 8 buttons.
 *
 *VERSION HISTORY:
 *  v0.4  Small update to adapt to PlatformIO.
 *	v0.3	Removed SFR_OFFSET fix.
 *	v0.2	Fixed wrong pin direction for keys (worked for a while with key at
 *        output port).
 *	v0.1	Initial test version.
 *
 *DESCRIPTION:
 *	Routines for detecting key press and release with de-bouncing function and key
 *  repeat detection when a key is kept pressed for a longer time.
 *	This library support up to 8 keys. De-bouncing is implemented by 4 samples of key
 *  state.
 *	PORTB is used for the button input pins (available on all AVR MCUs). Note that the
 *  smaller ATTiny MCUs have up to 6 I/O pins on port B (PB0-PB5), while we support a
 *  maximum of 8 buttons.
 *	Trying to use I/O pins not available, or programmed for other purposes, produces
 *  undefined	results.
 *
 *NOTES:
 *	1.	These routines are based on the de-bouncing routines in C, written by Peter
 *      Dannegger.
 *	2.	It is assumed that all generic initialization, like stack pointer setup is done
 *      by the calling program.
 *	3.	This library defines one interrupt vector (TIMER0_OVF); all other vectors are
 *      up to the caller.
 *	4.	When TIMER0 is used elsewhere, you could modify the source and include it with
 *			your program.
 *	5.	For examples on how to call these routines see the avr_buttons_test.asm source.
 *			That program can also be used to test the key routines if you need to change it.
 *
 *COPYRIGHT:
 *	(c)2016 by Ron Moerman.
 *	This program comes with ABSOLUTELY NO WARRANTY. Use at your own risk.
 *	This is free software, and you are welcome to redistribute it under certain
 *  conditions.
 *	The program and its source code are published under the GNU General Public License
 *  (GPL). See http://www.gnu.org/licenses/gpl-3.0.txt for details.
 *
 *	$File: avr_buttons.S $
 *	$Revision: 0.4 $
 *	$Compiler: AVR-GCC AS $
 *	$Author: Ron Moerman $
 *	$Email: ron@electronicsworkbench.io $
 *	$Date: Sunday, May 22, 2016 20:07:23 UTC $
 *=====================================================================================*/

#define ___KEYS_LIB___						 	;To make the function prototypes available

/*======================================================================================
 *                            I N C L U D E   H E A D E R S
 *=====================================================================================*/
 #define __SFR_OFFSET	0

		.nolist
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr_macros.h>
		.list
#include <avr_buttons.h>

/*======================================================================================
 *                    D E V I C E   D E P E N D E N T   D E F I N E S
 *=====================================================================================*/

//--- The makefile should define F_CPU.
#ifndef F_CPU
 #error "F_CPU not defined."
#endif

#if defined(__AVR_ATtiny2313__)||defined(__AVR_ATtiny2313A__)||defined(__AVR_ATtiny4313__)
 #define KEY_TCCR TCCR0B
 #define KEY_TCNT TCNT0
 #define KEY_TOIE (1<<TOIE0)
 #define KEY_TIMSK TIMSK
 #define KEY_CLKDIV ((1<<CS02)|(1<<CS00))		//F_clock divided by 1024
#else
 #if defined(__AVR_ATtiny85__)||defined(__AVR_ATtiny85A__)
  #define KEY_TCCR TCCR0B
  #define KEY_TCNT TCNT0
  #define KEY_TOIE (1<<TOIE0)
  #define KEY_TIMSK TIMSK
  #define KEY_CLKDIV ((1<<CS02)|(1<<CS00))		//F_clock divided by 1024
 #else
  #error "Only ATtiny2313/ATtiny2313A/ATtiny4313/ATtiny85/ATtiny85A supported (for now)"
 #endif
#endif
//--- Calculate (at compile time) timer overflow value for 10ms (100Hz) count.
#define KEY_TIMER_OVF  78   //((F_CPU/1024)/100)

/*======================================================================================
 *                                   C O N S T A N T S
 *=====================================================================================*/

//--- Repeat timing constants.
#define REPEAT_START 50					  //Repeat kicks in after 500ms.
#define	REPEAT_NEXT 20						//Repeat every 200ms.

//--- Ports and pins for the keys.
#define KEY_DDR DDRB							//Use PINB as button inputs.
#define KEY_PORT PORTB						//Input port for pins PBn.

/*======================================================================================
 *                          L I N K E R   D E F I N I T I O N S
 *=====================================================================================*/

//--- Interrupt service routine.
		.global TIMER0_OVF_vect					;TIMER0 Overflow interrupt routine entry point.

/*======================================================================================
 *                     L I B R A R Y   L O C A L   V A R I A B L E S
 *=====================================================================================*/
		.section .data

//--- Save the active keys mask passed during initialization here.
key_mask:
		.byte	0
//--- Save the repeat keys mask passed during initialization here.
rpt_mask:
		.byte	0
//--- Status variables holding the intermediate values of key pressed states.
key_state:
		.byte	0										      ;Debounced & inverted key state (1: key pressed).
key_press:
		.byte	0										      ;Key press detect.
key_rpt:
		.byte	0										      ;Key repeat detect.
//--- 8x 2-bit counters, counting down from 3 to 0 to handle debouncing.
key_ct0: .byte	0
key_ct1: .byte	0
; Repeat key counter.
rpt_cnt: .byte	0

/*======================================================================================
 *                          I N T E R R U P T   R O U T I N E S
 *=====================================================================================*/
		.section .text

/*--------------------------------------------------------------------------------------
 * TIMER0_OVF_vect: ISR triggered on Timer0 Overflow.
 *--------------------------------------------------------------------------------------
 *DESCRIPTION:
 *		ISR triggered on Timer0 Overflow. Set to fire every few ms to detect key bounce.
 *INPUT:
 *		None.
 *OUTPUT:
 *		None.
 *REGISTER USAGE:
 *		R0.
 *LOCAL STACK USAGE:
 *		10 bytes.
 *NOTES:
 *		1.This ISR consumes up to 72 CPU cycles, including reacting to the timer
 *			interrupt and returning	to the running code.
 *-------------------------------------------------------------------------------------*/
TIMER0_OVF_vect:
//--- Save status and used working registers.
		in		R0,_SFR_IO8(SREG)					;Save status register.
		push	R16										    ;Save working registers.
		push	R9
		push  R8
		push	R7
//--- Reload timer count down register with overflow value.
		ldi		R16,KEY_TIMER_OVF
		out		_SFR_IO8(KEY_TCNT),R16
//--- Read the button port(s) and reverse the bits.
		in		R16,KEY_PORT              //Get button states.
		com		R16										    ;Invert the bits: make '1' the pressed state.
		lds		R7,key_mask								;Get the keys mask bits for filtering active keys.
		and		R16,R7									  ;Filter out non-button pins.
//--- Check for key change.
		lds		R7,key_state							;Get current key state in R7.
		eor		R16,R7									  ;Set mask for changed keys.
//--- R8 and R9 are a pair of 2-bit key counters.
//--- Count a key state.
		lds		R8,key_ct0								;Get key counters.
		lds		R9,key_ct1
		and		R8,R16									  ;Count low bit.
		com		R8
		and		R9,R16									  ;Count high bit.
		eor		R9,R8
		sts		key_ct0,R8								;Update key counters in memory.
		sts		key_ct1,R9
		and		R8,R9									    ;Count until roll over?
		and		R6,R8
//--- Toggle debounce state.
		eor		R7,R16
		sts		key_state,R7							;Save new key-state.
//--- From 0->1: key press detect.
		and		R16,R7
		lds		R8,key_press
		or		R8,R16
		sts		key_press,R8							;Save key-pressed byte.
//--- Check for long pressed (repeat) key.
		lds		R8,rpt_mask								;Get key mask to check for repeat state in R8.
		mov		R9,R8									    ;Save repeat key mask for later.
		and		R8,R7									    ;Mask with current key state.
		lds		R16,rpt_cnt								;Get repeat counter.
		brne	1f                        ;Skip if no repeat key pressed.
//--- Start repeat delay function.
		ldi		R16,REPEAT_START					;R16 holds repeat counter.
1:	dec		R16										  	;Count a repeat cycle.
		brne	2f
		ldi		R16,REPEAT_NEXT           ;Set repeat delay.
		and		R7,R9                     ;Mask repeat keys.
		lds		R8,key_rpt								;Get current repeat status.
		or		R8,R7
		sts		key_rpt,R8								;Save updated repeat status.
2:	sts		rpt_cnt,R16								;Save repeat delay counter.
//--- Restore and return.
		pop		R7
		pop		R8
		pop		R9
		pop		R16										    ;Restore working registers.
		out		_SFR_IO8(SREG),R0					;Restore status register and return.
		reti

/*======================================================================================
 *                           L I B R A R Y   R O U T I N E S
 *=====================================================================================*/

/*--------------------------------------------------------------------------------------
 * keys_pressed: Check if any of the specified keys have been pressed.
 *--------------------------------------------------------------------------------------
 *DESCRIPTION:
 *		Check if one ore more keys have been pressed. Each pressed key is reported only
 *		once.
 *INPUT:
 *		R24 = key mask to inquire.
 *OUTPUT:
 *		R24 = key mask of pressed keys.
 *REGISTER USAGE:
 *		R24.
 *LOCAL STACK USAGE:
 *		3 bytes, including calling this routine.
 *NOTES:
 *		1. This routine consumes 17 CPU cycles, including returning to the caller.
 *-------------------------------------------------------------------------------------*/
		.func	keys_pressed
keys_pressed:
		push	R16										    ;Save used register. (2)
		cli                             ;Read and clear should be atomic. (1)
//--- Read the keys and strip the ones we don't want to read.
		lds		R16,key_press							;Get the keys we are interested in. (3)
		and		R24,R16
//--- Clear the keys we just read.
		eor		R16,R24                   ;Clear keys after reading. (3)
		sts		key_press,R16
//--- Return pressed keys in R24 (KEY0..KEY7).
		sei                             ;Restore global interrupt state. (1)
		tst		R24										    ;Z=0 if one or more of the requested keys are pressed. (1)
		pop		R16										    ;Restore used register & return. (6)
		ret
		.endfunc

/*--------------------------------------------------------------------------------------
 * keys_repeat: Check if any of the specified keys is long pressed.
 *--------------------------------------------------------------------------------------
 *DESCRIPTION:
 *		Check if one ore more keys are pressed long enough for the repeat functionality to
 *		to kick in. Each pressed key is reported only once. After a small setup delay, the
 *		key is reported being	pressed in subsequent calls to this function. This simulates
 *		the user repeatedly pressing and releasing the key.
 *INPUT:
 *		R24 = key repeat mask.
 *OUTPUT:
 *		R24 = key mask of long pressed keys.
 *REGISTER USAGE:
 *		R24.
 *LOCAL STACK USAGE:
 *		3 bytes, including calling this routine.
 *NOTES:
 *		1.This routine consumes ~18 CPU cycles, including returning to the caller.
 *-------------------------------------------------------------------------------------*/
    .func	keys_repeat
keys_repeat:
    push  R16                       ;Save used register.
    cli                             ;Read and clear should be atomic.
//--- Read the keys and strip the ones we don't want to read.
    lds   R16,key_rpt               ;Get the keys we are interested in.
    and   R24,R16
//--- Clear the keys we just read.
    eor   R16,R24                   ;Clear repeat keys after reading.
    sts   key_rpt,R16
//--- Return pressed keys in R24 (KEY0..KEY7).
    sei                             ;Restore global interrupt state.
    tst   R24                       ;Z=0 if one or more of the keys are long pressed.
    pop   R16                       ;Restore used register & return.
    ret
    .endfunc

/*--------------------------------------------------------------------------------------
 * keys_state: Check if any is pressed right now.
 *--------------------------------------------------------------------------------------
 *DESCRIPTION:
 *    Check if one or more keys is pressed right now. The pressed state is not altered.
 *INPUT:
 *    R24 = key mask defining keys to inquire.
 *OUTPUT:
 *    R24 = key mask of currently pressed keys.
 *REGISTER USAGE:
 *    R24.
 *STACK USAGE:
 *    ? bytes, including calling this routine.
 *NOTES:
 *    1.This routine consumes ~11 CPU cycles, including returning to the caller.
 *-------------------------------------------------------------------------------------*/
		.func	keys_state
keys_state:
    push  R16                       ;Save used register.
    lds   R16,key_state             ;Get current key state.
    and   R24,R16                   ;Mask relevant keys.
    pop   R16                       ;Restore used register and return.
    ret
		.endfunc


/*--------------------------------------------------------------------------------------
 * keys_short: Check if any of the specified keys is currently short pressed.
 *--------------------------------------------------------------------------------------
 *DESCRIPTION:
 *    Check if one ore more keys is currently short pressed. Each pressed key is reported
 *    only once.
 *INPUT:
 *    R24 = key mask for inquiry on specified keys only.
 *OUTPUT:
 *    R24 = key mask of currently (short) pressed keys.
 *REGISTER USAGE:
 *    R24.
 *STACK USAGE:
 *    ? bytes, including calling this routine.
 *NOTES:
 *    1.This routine consumes ~xx CPU cycles, including returning to the caller.
 *-------------------------------------------------------------------------------------*/
		.func	keys_short
keys_short:
		push	R16
		cli												      ;Read key state and key press atomic. (1)
		lds		R16,key_state
		com		R16
		and		R24,R16
		rcall	keys_pressed							;Get relevant pressed keys.
		sei
		pop		R16
		ret
		.endfunc

/*--------------------------------------------------------------------------------------
 * keys_long: Check if any of the specified keys have been long pressed.
 *--------------------------------------------------------------------------------------
 *DESCRIPTION:
 *    Check if one ore more keys have been long pressed. Each pressed key is reported
 *    only once.
 *INPUT:
 *    R24 = key mask for inquiry on only specified keys.
 *OUTPUT:
 *    R24 = key mask of long pressed keys.
 *REGISTER USAGE:
 *    R24.
 *STACK USAGE:
 *    ? bytes, including calling this routine.
 *NOTES:
 *    1.This routine consumes xx CPU cycles, including returning to the caller.
 *-------------------------------------------------------------------------------------*/
		.func	keys_long
keys_long:
		rcall	keys_repeat								;Get the repeat keys state.
		rjmp	keys_pressed							;Map to pressed keys to see if still pressed.
		.endfunc

/*--------------------------------------------------------------------------------------
 * keys_init: Initialize the key press library for the needed keys.
 *--------------------------------------------------------------------------------------
 *DESCRIPTION:
 *    Initialize the key press library for the needed number of keys.
 *INPUT:
 *    R24 = key mask bit specifying the keys to 'activate'.
 *    R25 = key repeat mask bit specifying the keys to detect repeat for.
 *OUTPUT:
 *    R24 = 0 (and CF=0): OK.
 *REGISTER USAGE:
 *    R24,R25.
 *LOCAL STACK USAGE:
 *    2 bytes.
 *NOTES:
 *    1.This routine uses 27CPU cycles, including returning to caller.
 *-------------------------------------------------------------------------------------*/
		.func	keys_init
keys_init:
//--- Save the key and repeat masks in SRAM for use in timer interrupt routine to filter
//		out unused keys and detect repeat state (long pressed) of key.
//		Use KEY0-KEY7 bits to indicate used key input pins (on port KEY_PORT).
    sts   key_mask,R24              //Key_mask holds the used keys mask.
    sts   rpt_mask,R25              //Rpt_mask holds the keys to detect repeat.
//--- Configure key input ports; connect keys as 'close to ground'.
// 		:
// 		|
// 	PBn	+-----------+
// 		|			|
// 		|		 S1	 /
// 	PBm	+--..		|
// 		|			|
// 		:		   GND
//
		com   R24                       //Inverse key mask, since 0 makes it input pin.
    out   KEY_DDR,R24               //Configure key port(s) for input.
    com   R24                       //Revert key mask back again.
    out   KEY_PORT,R24              //Turn on pull up resistors by writing a 1
                                    //to input port pins.
//--- Set up timer to frequently poll key pressed state (every 10ms).
		ldi		R24,KEY_CLKDIV						;Get timer divider.
		out		_SFR_IO8(KEY_TCCR),R24			;Set divider in Timer Control Register.
		ldi		R24,KEY_TIMER_OVF					;Get calculated timer overflow value.
		out		_SFR_IO8(KEY_TCNT),R24			;Set timer overflow to about 10ms.
		ldi		R24,KEY_TOIE							;Get timer overflow interrupt enable mask.
		out		_SFR_IO8(KEY_TIMSK),R24		;Enable timer interrupt.
//--- Initialize key state variables.
		sts		key_state,ZEROR						;Clear the actual key_state bits.
		sts		key_press,ZEROR						;Clear the key pressed indication bits.
//--- Return OK (0).
		clr		R24										    ;Return OK in R24.
		ret
		.endfunc

		.end
