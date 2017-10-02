/*==================================================================================================*;
;*SYNOPSIS:																							*;
;*	Header FILE for key debouncing and detection library routines with repeat detection for 8-bit	*;
;*	AVR MCUs.																						*;
;*																									*;
;*VERSION HISTORY:																					*;
;*	20141107 v0.2	Added repeat/long pressed functions.											*;
;*	20141026 v0.1	Initial test version.															*;
;*																									*;
;*DESCRIPTION:																						*;
;*	Routines for detecting key press and release with debouncing function and key repeat detection	*;
;*	when a key is kept pressed for a longer time. These routines support up to 8 keys.				*;
;*	Debouncing is implemented by 4 samples of key state.											*;
;*	PORTB is used for the button input pins (available on all AVR MCUs). Note that the smallest		*;
;*	ATtiny MCUs have up to 6 I/O pins on port B (PB0-PB5), while these functions support a maximum	*;
;*	of 8 buttons. Trying to use I/O pins not available, or assigned other functions, produces		*;
;*	undefined results.																				*;
;*																									*;
;*NOTES:																							*;
;*	1. It is assumed that all generic initialization, like stackpointer setup is done by the		*;
;*		calling program.																			*;
;*	2.	This library defines one interrupt vector (TIMER0_OVF); all other vectors are up to the		*;
;*		calling program.																			*;
;*																									*;
;*COPYRIGHT:																						*;
;*	(c)2014 by Ron Moerman, All Rights Reserved.													*;
;*																									*;
;*	This program comes with ABSOLUTELY NO WARRANTY.													*;
;*	This is free software, and you are welcome to redistribute it under certain conditions.			*;
;*	The program and its source code are published under the GNU General Public License (GPL).		*;
;*	See http://www.gnu.org/licenses/gpl-3.0.txt for details.										*;
;*																									*;
;*	$File: keys.h $																					*;
;*	$Revision: 0.2 $																				*;
;*	$ASM: AVR-GCC AS $																				*;
;*	$Author: Ron Moerman $																			*;
;*	$Email: ron@moerman.cc $																		*;
;*	$Date: Sunday, Nov 07, 2014 19:17:21 UTC $														*;
;*==================================================================================================*/

#ifndef ___AVR_BUTTONS_H___
#define ___AVR_BUTTONS_H___

/*==================================================================================================*;
;*                                   I N C L U D E   H E A D E R S                                  *;
;*==================================================================================================*/
//----- None -----

/*==================================================================================================*;
;*                                         C O N S T A N T S                                        *;
;*==================================================================================================*/

//--- Key mask bits for all 8 keys.
#define KEY0 DDB0
#define KEY1 DDB1
#define KEY2 DDB2
#define KEY3 DDB3
#define KEY4 DDB4
#define KEY5 DDB5
#define KEY6 DDB6
#define KEY7 DDB7


/*==================================================================================================*;
;*                               F U N C T I O N   P R O T O T Y P E S                              *;
;*==================================================================================================*/

/*--------------------------------------------------------------------------------------------------*;
;* keys_pressed: Check if any of the specified keys have been pressed.								*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if one ore more keys have been pressed. Each pressed key is reported only once.			*;
;*																									*;
;*INPUT:																							*;
;*	R24 = key mask.																					*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = key mask of pressed keys.																	*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R24.																							*;
;*																									*;
;*LOCAL STACK USAGE:																				*;
;*	3 bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes 17 cpu cycles, including returning to the calling program.			*;
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___KEYS_LIB___
		.extern keys_pressed
#else
		.global keys_pressed
#endif

/*--------------------------------------------------------------------------------------------------*;
;* keys_repeat: Check if any of the specified keys is long pressed.									*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if one ore more keys are pressed long enough for the repeat functionality to kick in.		*;
;*	Each pressed key is reported only once. After a small setup delay, the key is reported being	*;
; *	pressed in subsequent calls to this function. Thiis simulates the user repeatedly pressing and	*;
;*	releasing the key.																				*;
;*																									*;
;*INPUT:																							*;
;*	R24 = key repeat mask.																			*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = key mask of long pressed keys.															*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R24.																							*;
;*																									*;
;*LOCAL STACK USAGE:																				*;
;*	3 bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes 17 cpu cycles, including returning to the calling program.			*;
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___KEYS_LIB___
		.extern keys_repeat
#else
		.global keys_repeat
#endif


/*--------------------------------------------------------------------------------------------------*;
;* keys_state: Check if any is pressed right now.													*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if one or more keys is pressed right now. The pressed state is not altered.				*;
;*																									*;
;*INPUT:																							*;
;*	R24 = key mask.																					*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = key mask of currently pressed keys.														*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	? bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes 1 cpu cycles, including returning to the calling program.				*;
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___KEYS_LIB___
		.extern	keys_state
#else
		.global keys_state
#endif

/*--------------------------------------------------------------------------------------------------*;
;* keys_short: Check if any of the specified keys is currently short pressed.						*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if one ore more keys is currently short pressed. Each pressed key is reported only once.	*;
;*																									*;
;*INPUT:																							*;
;*	R24 = key mask.																					*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = key mask of currently (short) pressed keys.												*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	? bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes xx cpu cycles, including returning to the calling program.			*;
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___KEYS_LIB___
		.extern	keys_short
#else
		.global keys_short
#endif

/*--------------------------------------------------------------------------------------------------*;
;* keys_long: Check if any of the specified keys have been long pressed.							*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Check if one ore more keys have been long pressed. Each pressed key is reported only once.		*;
;*																									*;
;*INPUT:																							*;
;*	R24 = key mask.																					*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = key mask of long pressed keys.															*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R24.																							*;
;*																									*;
;*STACK USAGE:																						*;
;*	? bytes, including calling this routine.														*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine consumes xx cpu cycles, including returning to the calling program.			*;
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___KEYS_LIB___
		.extern	keys_long
#else
		.global keys_long
#endif

/*--------------------------------------------------------------------------------------------------*;
;* keys_init: Initialize the key press library for the needed keys.									*;
;*--------------------------------------------------------------------------------------------------*;
;*DESCRIPTION:																						*;
;*	Initialize the key press library for the needed number of keys.									*;
;*																									*;
;*INPUT:																							*;
;*	R24 = key mask bit specifying the keys to 'activate'.											*;
;*	R25 = key repeat mask bit specifying the keys to detect repeat.									*;
;*																									*;
;*OUTPUT:																							*;
;*	R24 = 0 (and CF=0): OK.																			*;
;*																									*;
;*REGISTER USAGE:																					*;
;*	R24,R25.																						*;
;*																									*;
;*LOCAL STACK USAGE:																				*;
;*	2 bytes.																						*;
;*																									*;
;*NOTES:																							*;
;*	1.	This routine uses xx cpu cyles, including returning to calling program.						*;
;*--------------------------------------------------------------------------------------------------*/
#ifndef ___KEYS_LIB___
		.extern	keys_init
#else
		.global keys_init
#endif

#endif //___AVR_BUTTONS_H___
