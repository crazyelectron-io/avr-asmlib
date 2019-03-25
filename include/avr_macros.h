;*****************************************************************
;*****************************************************************
;*	file: avr_macros.h
;*
;*	Description:
;*	Source file for application note AVR001 - Conditional Assembly
;*	and Portability Macros.
;*
;*	Defines a number of macros that makes it easier to access
;*	Defines a number of macros that makes it easier to access
;*	IO registers and extended IO registers (or SRAM locations up
;*  to adress $FF if applicable).
;*	The macros can be used to produce code that assembles to
;*	any target AVR, without considering if the accessed IO
;*	registers are located in low, standard or extended IO space
;*
;* $Revision: 2.2 $
;* $Author: jllassen $
;* $Date: Wednesday, January 26, 2005 10:55:18 UTC $
;*****************************************************************

#ifndef __AVR_MACROS__H__
#define __AVR_MACROS__H__
#include <avr/io.h>

;*==================================================================================================*;
;* Define special registers.																		*;
;*==================================================================================================*;

		.set	RETR, 24							;Register for function return value.
		.set	ZEROR, 1							;Register holding the value 0.
		.set	TMPR, 16							;Working register can be used/destroyed (except in ISR's).


;*--------------------------------------------------------------------------------------------------*;
;* SETB - Set Bit anywhere in I/O or lower 0xFF of data space.										*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		\io - Address of I/O register (or lower memory) to set;
;*			\bit - Bit to set (0-7);
;*			\wrk (optional) - 0-31: use as working reg, not defined: use R16.
;* OUT:		None.
;* REGS:	R16 if \wrk not defined;
;*			\wrk if \wrk <= 0x1F;
;*			None otherwise.
;* STACK:	else: 0 bytes.
;* FLAGS:	Z, N, V, C.
;*--------------------------------------------------------------------------------------------------*;
.macro SETB	io:req, bit:req, wrk
	.if \bit > 7
		.error "Only values 0-7 allowed for Bit parameter in SETB macro"
	.endif
	.ifnb \wrk
		.if \wrk > 0x1F
			.error "Register parameter out of range for SETB macro"
		.endif
		.set WREG, \wrk
	.else
		.set WREG, 0x10
	.endif

	.if \io > 0x3F
		lds		WREG,\io
		sbr		WREG,(1<<\bit)
		sts		\io,WREG
	.else
		.if \io > 0x1F
			in		WREG,\io
			sbr		WREG,(1<<\bit)
			out		\io,WREG
		.else
			sbi		\io,\bit
		.endif
	.endif
.endm


;*--------------------------------------------------------------------------------------------------*;
;* CLRB - Clear Bit anywhere in I/O or lower 0xFF of data space.									*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		\io - Address of I/O register (or lower memory) to clear;
;*			\bit - Bit to clear (0-7);
;*			\wrk (optional) - 0-31: use as working reg, not defined: use R16.
;* OUT:		None.
;* REGS:	R16 if @2 not defined;
;*			@2 if @2<=0x1F;
;*			None otherwise.
;* STACK:	if (@>31 && @2=0xFF): 2 bytes;
;*			else: 0 bytes.
;* FLAGS:	Z, N, V, C.
;*--------------------------------------------------------------------------------------------------*;
.macro CLRB	io:req bit:req wrk
	.if \bit > 7
		.error "Only values 0-7 allowed for Bit parameter in CLRB macro"
	.endif

	.ifnb \wrk
		.if \wrk > 0x1F
			.error "Register parameter out of range for CLRB macro"
		.endif
		.set WREG = \wrk
	.else
		.set WREG = 16
	.endif

	.if \io > 0x3F
		lds		WREG,\io
		cbr		WREG,(1<<\bit)
		sts		\io,WREG
	.elif \io > 0x1F
		in		WREG,\io
		cbr		WREG,(1<<\bit)
		out		\io,WREG
	.else
		cbi		\io,\bit
	.endif
.endm


/*--------------------------------------------------------------------------------------------------*
 *     SKBS - Skip if Bit Set anywhere in I/O or lower 0xFF of data space.							*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - Address of I/O register (or lower memory) to test;
 *			@1 - Bit to test (0-7);
 *			@2 (optional) - 0-31: use as working reg, 0xFF: use temporary reg, not defined: use R16.
 * OUT:		None.
 * REGS:	R16 if @2 not defined;
 *			@2 if @2<=0x1F;
 &			None otherwise.
 * STACK:	if (@>31 && @2=0xFF): 2 bytes;
 *			else: 0 bytes.
 * FLAGS:	Z, N, V, C.
 */
.MACRO SKBS
	.if @1>7
		.error "Only values 0-7 allowed for Bit parameter of SKBS macro"
	.endif
	#define SKBSSAVE 0
	.ifnb @2
		.if @2==0xFF
			.SET WREG = R16
			.if @0>0x1F
				.SET SKBSSAVE = 1
			.endif
		.elif @2>0x1F
			.error "Register parameter out of range for SKBS macro"
			.SET WREG = @2
		.endif
	.else
		.SET WREG = R16
	.endif
	.if SKBSSAVE==1
		push	WREG
	.endif

	.if @0>0x3F
		lds  WREG,@0
		sbrs WREG,@1
	.elif @0>0x1F
		in   WREG,@0
		sbrs WREG,@1
	.else
		sbis @0,@1
	.endif

	.if SKBSSAVE==1
		pop		WREG
	.endif
.ENDM

/*--------------------------------------------------------------------------------------------------*
 *     SKBC - Skip if Bit Cleared anywhere in I/O or lower 0xFF of data space.						*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - Address of I/O register (or lower memory) to test;
 *			@1 - Bit to test (0-7);
 *			@2 (optional) - 0-31: use as working reg, 0xFF: use temporary reg, not defined: use R16.
 * OUT:		None.
 * REGS:	R16 if @2 not defined;
 *			@2 if @2<=0x1F;
 &			None otherwise.
 * STACK:	if (@>31 && @2=0xFF): 2 bytes;
 *			else: 0 bytes.
 * FLAGS:	Z, N, V, C.
 */
.macro SKBC  		;Arguments: Address, Bit, Register
	.if @1>7
		.error "Only values 0-7 allowed for Bit parameter in SKBC macro"
	.endif
	.SET SKBCSAVE = 0
	.ifnb @2
		.if @2==0xFF
			.SET WREG = R16
			.if @0>0x1F
				.SET SKBCSAVE = 1
			.endif
		.elif @2>0x1F
			.error "Register parameter out of range for SKBC macro"
			.SET WREG = @2
		.endif
	.else
		.SET WREG = R16
	.endif
	.if SKBCSAVE==1
		push	WREG
	.endif

	.if @0>0x3F
		lds		WREG,@0
		sbrc	WREG,@1
	.elif @0>0x1F
		in		WREG,@0
		sbrc	WREG,@1
	.else
		sbic	@0,@1
	.endif

	.if SKBCSAVE==1
		pop		WREG
	.endif
.endm


/*--------------------------------------------------------------------------------------------------*
 *     OUTP - Output byte anywhere to I/O or lower 0xFF of data space.								*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - Address of I/O register to store byte;
 *			@1 - Register containing byte value to output.
 * OUT:		None.
 * REGS:	None.
 * STACK:	0 bytes.
 * FLAGS:	None.
 */
.MACRO OUTP
	.if	@0>0x3F
		sts		@0,@1
	.else
		out		@0,@1
	.endif
.ENDM

/*--------------------------------------------------------------------------------------------------*
 *     INP - Input byte from anywhere in I/O or lower 0xFF of data space.							*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - Register to receive i/O port byte;
 *			@1 - Address of I/O register (or lower memory) to read from.
 * OUT:		@0 - Register containing I/O register value.
 * REGS:	@0.
 * STACK:	0 bytes.
 * FLAGS:	None.
 */
.MACRO INP
	.if	@1>0x3F
		lds		@0,@1
	.else
		in		@0,@1
	.endif
.endm

/*--------------------------------------------------------------------------------------------------*
 *     OUTI - Output immediate value to I/O or lower 0xFF of data space.								*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - Address of I/O register or lower 0xFF of data space to receive byte;
 *			@1 - Value to output.
 * OUT:		None.
 * REGS:	None.
 * STACK:	0 bytes.
 * FLAGS:	None.
 */
.MACRO OUTI p1:req p2:req
	.if \p1 < 0x100
		sts		\p1,\p2
	.else
		.error "OUTI register address out of range (>0xFF)."
	.endif
.ENDM


;*--------------------------------------------------------------------------------------------------*;
;*     SWAPR - Swap values between two registers.													*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		\preg1 - First register;
;*			\preg2 - Second register;
;*			@\psave (opt.) - save flags if present, 0-31: use as working reg, >31 use R16.
;* OUT:		Register values swapped.
;* REGS:	@0, @1, @2 (if 0<=@2<=31).
;* STACK:	if @2>0x1F: 2 bytes;
;*			else: 0 bytes.
;* FLAGS:	if @2: none;
;*			else: Z, N, V, S.
;*--------------------------------------------------------------------------------------------------*;
.macro SWAPR preg1:req preg2:req psave
	.ifnb \psave
		.if \psave > 0x1F
			.SET WREG = 16
			push	WREG
		.else
			.SET WREG = \psave
		.endif
		in		WREG,SREG
	.endif
		eor		\preg1,\preg2						;@0 := @0 xor @1 (@0: a -> ab
		eor		\preg2,\preg1						;@1 := @1 xor @0 (@1: b -> bab -> a)
		eor		\preg1,\preg2						;@0 := @0 xor @1 (@0: ab -> aba ->b)
	.ifnb \psave
		out		SREG,WREG
		.if \psave > 0x1F
			pop		WREG
		.endif
	.endif
.endm


;*--------------------------------------------------------------------------------------------------*;
;* SWAPXY - Swap X and Y registers.																	*;
;*--------------------------------------------------------------------------------------------------*;
;* PARAM:	\psave (opt.) - save flags if present, 0-31: use as working reg, else use R16.
;* OUT:		X, Y register values swapped.
;* REGS:	X, Y, \psave (if 0<=\psave<=31).
;* STACK:	if \psave > 0x1F: 2 bytes;
;*			else: 0 bytes.
;* FLAGS:	if \psave: none;
;*			else: Z, N, V, S.
;*--------------------------------------------------------------------------------------------------*;
.macro SWAPXY psave
	.ifnb \psave
		.if \psave > 0x1F
			.SET WREG = 16
			push	WREG
		.else
			.SET WREG = \psave
		.endif
		in		WREG,SREG
	.endif
		eor		YL,XL
		eor		XL,YL
		eor		YL,XL
		eor		YH,XH
		eor		XH,YH
		eor		YH,XH
	.ifnb \psave
		out		SREG,WREG
		.if \psave > 0x1F
			pop		WREG
		.endif
	.endif
.endm


/*--------------------------------------------------------------------------------------------------*
 *     SWAPXZ - Swap X and Z registers.																*
 *--------------------------------------------------------------------------------------------------*
 * IN:		X, Z registers (16 bit);
 *			@0 (optional) - save flags if present, 0-31: use as working reg, else use temporary reg.
 * OUT:		X, Z register values swapped.
 * REGS:	X, Z, @0 (if 0<=@0<=31).
 * STACK:	if @0>0x1F: 2 bytes;
 *			else: 0 bytes.
 * FLAGS:	if @0: none;
 *			else: Z, N, V, S.
 */
.MACRO SWAPXZ
	.ifnb @0
		.if @0>0x1F
			.SET WREG = R16
			push	WREG
		.else
			.SET WREG = @0
		.endif
		in		WREG,SREG
	.endif
		eor		ZL,XL
		eor		XL,ZL
		eor		ZL,XL
		eor		ZH,XH
		eor		XH,ZH
		eor		ZH,XH
	.ifnb @0
		out		SREG,WREG
		.if @0>0x1F
			pop		WREG
		.endif
	.endif
.ENDM


/*--------------------------------------------------------------------------------------------------*
 *     SWAPYZ - Swap Y and Z registers.																*
 *--------------------------------------------------------------------------------------------------*
 * IN:		Y, Z registers (16 bit);
 *			@0 (optional) - save flags if present, 0-31: use as working reg, else use temporary reg.
 * OUT:		Y, Z register values swapped.
 * REGS:	Y, Z, @0 (if 0<=@0<=31).
 * STACK:	if @0>0x1F: 2 bytes;
 *			else: 0 bytes.
 * FLAGS:	if @0: none;
 *			else: Z, N, V, S.
 */
.MACRO SWAPYZ
	.ifnb @0
		.if @0>0x1F
			.SET WREG = R16
			push	WREG
		.else
			.SET WREG = @0
		.endif
		in		WREG,SREG
	.endif
		eor		ZL,YL
		eor		YL,ZL
		eor		ZL,YL
		eor		ZH,YH
		eor		YH,ZH
		eor		ZH,YH
	.ifnb @0
		out		SREG,WREG
		.if @0>0x1F
			pop		WREG
		.endif
	.endif
.ENDM


/*--------------------------------------------------------------------------------------------------*
 *     LDIX - Load X with address @1.																*
 *--------------------------------------------------------------------------------------------------*
 * IN:		\parg - address to load in 16 bit X register.
 * OUT:		X register loaded with address.
 * REGS:	X.
 * STACK:	0 bytes.
 * FLAGS:	None.
 */
.macro LDIX	argaddr
		ldi		XL,lo8(\argaddr)
		ldi		XH,hi8(\argaddr)
.endm


/*--------------------------------------------------------------------------------------------------*
 *     LDIY - Load Y with address @1.																*
 *--------------------------------------------------------------------------------------------------*
 * IN:		\parg - address to load in 16 bit Y register.
 * OUT:		Y register loaded with address.
 * REGS:	Y.
 * STACK:	0 bytes.
 * FLAGS:	None.
 */
.macro LDIY	argaddr
		ldi		YL,lo8(\argaddr)
		ldi		YH,hi8(\argaddr)
.endm


/*--------------------------------------------------------------------------------------------------*
 *     LDIZ - Load Z with address @1.																*
 *--------------------------------------------------------------------------------------------------*
 * IN:		\parg - address to load in 16 bit Z register.
 * OUT:		Z register loaded with address.
 * REGS:	Z.
 * STACK:	0 bytes.
 * FLAGS:	None.
 */
.macro LDIZ	argaddr
		ldi		ZL,lo8(\argaddr)
		ldi		ZH,hi8(\argaddr)
.endm


/*--------------------------------------------------------------------------------------------------*
 *     PUSHX - Push X register on stack.															*
 *--------------------------------------------------------------------------------------------------*
 * IN:		None.
 * OUT:		X register on stack.
 * REGS:	None.
 * STACK:	-2 bytes.
 * FLAGS:	None.
 */
.macro PUSHX
		push	XL
		push	XH
.endm


/*--------------------------------------------------------------------------------------------------*
 *     PUSHY - Push Y register on stack.															*
 *--------------------------------------------------------------------------------------------------*
 * IN:		None.
 * OUT:		Y register on stack.
 * REGS:	None.
 * STACK:	-2 bytes.
 * FLAGS:	None.
 */
.macro PUSHY
		push	YL
		push	YH
.endm


/*--------------------------------------------------------------------------------------------------*
 *     PUSHY - Push Z register on stack.															*
 *--------------------------------------------------------------------------------------------------*
 * IN:		None.
 * OUT:		Z register on stack.
 * REGS:	None.
 * STACK:	-2 bytes.
 * FLAGS:	None.
 */
.macro PUSHZ
		push	ZL
		push	ZH
.endm


/*--------------------------------------------------------------------------------------------------*
 *     POPX - Pull X register from stack.															*
 *--------------------------------------------------------------------------------------------------*
 * IN:		None.
 * OUT:		X register from stack.
 * REGS:	X.
 * STACK:	+2 bytes.
 * FLAGS:	None.
 */
.macro POPX
		pop		XH
		pop		XL
.endm


/*--------------------------------------------------------------------------------------------------*
 *     POPY - Pull Y register from stack.															*
 *--------------------------------------------------------------------------------------------------*
 * IN:		None.
 * OUT:		Y register from stack.
 * REGS:	Y.
 * STACK:	+2 bytes.
 * FLAGS:	None.
 */
.macro POPY
		pop		YH
		pop		YL
.endm


/*--------------------------------------------------------------------------------------------------*
 *     POPZ - Pull Z register from stack.															*
 *--------------------------------------------------------------------------------------------------*
 * IN:		None.
 * OUT:		Z register from stack.
 * REGS:	Z.
 * STACK:	+2 bytes.
 * FLAGS:	None.
 */
.macro POPZ
		pop		ZH
		pop		ZL
.endm


/*--------------------------------------------------------------------------------------------------*
 *     PUSHW - Push 16-bit register on stack.														*
 *--------------------------------------------------------------------------------------------------*
 * IN:		\p1 - register to push on stack (16 bit).
 * OUT:		Register on stack.
 * REGS:	None.
 * STACK:	-2 bytes.
 * FLAGS:	None.
 */
.macro PUSHW	p1:req
		push	\p1
		push	\p1+1
.endm


/*--------------------------------------------------------------------------------------------------*
 *     POPW - Pop 16-bit register from stack.														*
 *--------------------------------------------------------------------------------------------------*
 * IN:		\p1 - register to pop from stack (16 bit).
 * OUT:		Stack content in register.
 * REGS:	\p1.
 * STACK:	+2 bytes.
 * FLAGS:	None.
 */
.macro POPW	p1:req
		pop		\p1+1
		pop		\p1
.endm


/*--------------------------------------------------------------------------------------------------*
 * PUSHS - Push status register on stack.															*
 *--------------------------------------------------------------------------------------------------*
 * IN:		None.
 * OUT:		SREG on stack.
 * REGS:	None.
 * STACK:	-1 bytes.
 * FLAGS:	None.
 */
.MACRO PUSHS
		push	R16
		in		R16,SREG
		push	R16
.ENDM


;*--------------------------------------------------------------------------------------------------*;
;*     POPS - Pop status register from stack.														*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		SREG on stack.
;* OUT:		SREG restored.
;* REGS:	None.
;* STACK:	+1 bytes.
;* FLAGS:	None.
;*--------------------------------------------------------------------------------------------------*;
.macro POPS
		pop		R16
		out		SREG,R16
		pop		R16
.endm


;*--------------------------------------------------------------------------------------------------*;
;*     PUSHM - Push multiple registers to stack (recursive).										*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		\p1 - First register to push (required);
;*			\p2 (opt.) - Vararg of more registers to push.
;* REGS:	None.
;* STACK:	- # of registers pushed.
;* FLAGS:	None.
;*--------------------------------------------------------------------------------------------------*;
.macro PUSHM parg1:req, pargs:vararg
		push	\parg1
.ifnb \pargs
		PUSHM	\pargs
.endif
.endm


;*--------------------------------------------------------------------------------------------------*;
;* PUSHR - Push range of registers to stack (recursive).											*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		\pfrom - First register to push (required);
;*			\pto - Last register to push (required).
;* REGS:	None.
;* STACK:	+ # of registers popped.
;* FLAGS:	None.
;*--------------------------------------------------------------------------------------------------*;
.macro PUSHR pfrom:req, pto:req
		push	\pfrom
	.if \pto-\pfrom
		PUSHR	(\pfrom+1),\pto
	.endif
.endm


;*--------------------------------------------------------------------------------------------------*;
;* POPM - Revers pop of multiple registers from stack (recursive).									*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		\p1 - Last register to pop (required);
;*			\p2 (opt.) - Vararg of other registers to pop first.
;* REGS:	None.
;* STACK:	+ # of registers popped.
;* FLAGS:	None.
;* NOTE:	This macro pops the registers in reverse order to be compatible with PUSHM using the
;*			the same arguments.
;*--------------------------------------------------------------------------------------------------*;
.macro POPM parg1, pargs:vararg
	.ifnb \parg1
		POPM	\pargs
		pop		\parg1
	.endif
.endm


;*--------------------------------------------------------------------------------------------------*;
;* POPR - Pop range of registers from stack (recursive).											*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		\pfrom - First register pushed (required);
;*			\pto - Last register to pushed (required).
;* REGS:	None.
;* STACK:	+ # of registers popped.
;* FLAGS:	None.
;* NOTE:	Registers are popped in reverse order from \pto to \pfrom.
;*--------------------------------------------------------------------------------------------------*;
.macro POPR pfrom:req, pto:req
		pop		\pto
.if \pto-\pfrom
		POPR	\pfrom,(\pto-1)
.endif
.endm


/*--------------------------------------------------------------------------------------------------*
 *     SETSP - Load Stack Pointer with address @0.																*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - address to load in 16 bit SP register.
 * OUT:		SP register loaded with address.
 * REGS:	SP.
 * STACK:	0 bytes.
 * FLAGS:	None.
 */
 .MACRO SETSP
		OUTI	SPL,LOW(@0)
	.if (@0 > 0x00FF)							;Only for >256 byte SRAM MCUs.
		OUTI	SPH,HIGH(@0)
	.endif
.ENDM


/*--------------------------------------------------------------------------------------------------*
 *     BITR - Reverse the order of bits in a register byte.											*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - Register to get it's bits reversed.
 *			@1 (optional) - 0-31: use as working reg, 0xFF: use temporary reg, not defined: use R16.
 * OUT:		@0 - Register with reversed bits.
 * REGS:	@0, @1 (if 0<@1<0x20), TMPR (if @1 not defined).
 * STACK:	if @1=0xFF: 2 byets;
 *			else: 0 bytes.
 * FLAGS:	H, S, V, N, Z, C.
 */
.MACRO	BITR
	.SET BITRSAVE = 0
	.ifnb @1
		.if @1==0xFF
			.SET WREG = 16
			.SET BITRSAVE = 1
		.elif @1>0x1F
			.error "Register parameter out of range for BITR macro"
			.SET WREG = @1
		.endif
	.else
		.SET WREG = 16
	.endif
	.if BITRSAVE==1
		push	WREG
	.endif

		mov		WREG,@0						;Put input value in working register.
		lsl		WREG						;Shift input left into carry flag.
		ror		@0							;Rotate carry flag right into output.
		lsl		WREG						;Do it 8 times.
		ror		@0
		lsl		WREG
		ror		@0
		lsl		WREG
		ror		@0
		lsl		WREG
		ror		@0
		lsl		WREG
		ror		@0
		lsl		WREG
		ror		@0
		lsl		WREG
		ror		@0

	.if BITRSAVE == 1
		pop		WREG
	.endif
.ENDM


.MACRO ADD16	; Add16 UL,UH,VL,VH      U:=U+V
		add		@0,@2
		adc		@1,@3
.ENDM

.MACRO ADDI16	; Addi16 UL,UH,immediate   U:=U+immediate
		subi	@0,low(-@2)
		sbci	@1,high(-@2)
.ENDM

.MACRO SUB16	; Sub16 UL,UH,VL,VH	U:=U-V
		sub		@0,@2
		sbc		@1,@3
.endm

.MACRO SUBI16	; Subi16 UL,UH,immediate  U:=U-immediate
		subi	@0,low(@2)
		sbci	@1,high(@2)
.endm

.MACRO CMP16	; CP16 UL,UH,VL,VH	U-V
		cp		@0,@2
		cpc		@1,@3
.endm

.MACRO CPI16	; CP16 UL,UH,immediate	U-immediate
		cpi		@0,low(@2)
		ldi		mpr,high(@2)
		cpc		@1,mpr
.endm

.MACRO NEG16	; Neg16 UL,UH
		com		@0
		com		@1
		subi	@0,low(-1)
		sbci	@1,high(-1)
.endm


/*--------------------------------------------------------------------------------------------------*
 *     ADDI - Add immediate value to register.														*
 *--------------------------------------------------------------------------------------------------*
 * IN:		@0 - register to add value to;
 *			@1 - byte to add.
 * OUT:		@0.
 * REGS:	@0.
 * STACK:	0 bytes.
 * FLAGS:	All.
 * NOTES:	addi does not exist, but subi does...
 */
.macro ADDI
		subi	@0,(0xFF - @1 + 1)
.endm


/*--------------------------------------------------------------------------------------------------*
 *     ADIX - Add immediate value (16-bit) to X register.											*
 *--------------------------------------------------------------------------------------------------*
 * IN:		\parg - word to add.
 * OUT:		X loaded with \parg.
 * REGS:	X.
 * STACK:	0 bytes.
 * FLAGS:	All.
 * NOTES:	addi does not exist, but subi does...
 */
.macro ADIX
		subi	XL,(0xFF - lo8(\parg) + 1)
.endm


;*--------------------------------------------------------------------------------------------------*;
;* ENTERCRITICAL - Enter critical section (no interrupts).											*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		None.
;* OUT:		I-flag saved in T-flag;
;*			Interrupts disabled.
;* REGS:	None.
;* STACK:	0 bytes.
;* FLAGS:	I, T.
;* NOTES:	Save global interrupt state in T-flag and disable interrupts.
;*--------------------------------------------------------------------------------------------------*;
		.macro ENTERCRITICAL
		bclr	6									;Clear T flag.
		brid	1f									;Skip if interrupts disabled.
;Interrupts enabled, disable first and save state in T-flag.
		cli
		bset	6									;Set T-Flag to reflect global IE enabled state.
1:
		.endm


;*--------------------------------------------------------------------------------------------------*;
;*     EXITCRITICAL - Exit critical section.														*;
;*--------------------------------------------------------------------------------------------------*;
;* IN:		T-Flag reflects global interrupt state to restore.
;* OUT:		I-flag restored to state before 'ENTERCRITICAL'.
;* REGS:	None.
;* STACK:	0 bytes.
;* FLAGS:	I (if interrupts enabled again).
;* NOTES:	Restore global interrupt state from T-flag.
;*--------------------------------------------------------------------------------------------------*;
		.macro EXITCRITICAL
		brtc	1f
		sei
1:
		.endm

#endif /* __AVR_MACROS__H__ */
