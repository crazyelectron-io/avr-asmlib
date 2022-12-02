---
title: AVR library routines 1
description: Atmel AVR 8-bit library routines, part 1
img: avr.jpg
alt: Atmel AVR
---

Atmel (recently bought by Microchip) has been producing a large family of 8-bit microcontrollers, the tinyAVR and megaAVR series for quite some time. Actually the first Atmel 8-bit AVR was introduced back in 1997. You will probably find AVR's in many household devices throughout your house, from microwaves to coffee machines and some home automation devices.

Like most microcontrollers, they have many I/O options and are quite flexible. Memory however, especially on the ATTiny (tinyAVR) devices, is rather scarce. So I started to write some low-level assembler routines with minimal footprint to do basic stuff for the programs I want to develop, like queueing data, send and receiving serial data, allocating memory, reporting errors, writing EEPROM memory, etc.

===

## Inside the Atmel AVR 8-bit MCU

Before we look at the library routines, let's have a little peek under the hood of the Atmel 8-bit AVR family. The official Atmel datasheets are a good source for detailed descriptions of the various 8-bit ATTiny and ATMega MCU's, their components, interfaces, instruction set and I/O operations. That's how I learned to program them in the last year or so. A list of common 8-bit AVR's and their datasheets is included at the [end of this article](xxxxx). The ATTiny models range from the ATTiny4 with only 512 bytes of ROM and 32 bytes of RAM to the ATTiny167 with 16KB ROM, 512 bytes EPROM and 512 bytes RAM. The ATMega family starts with the ATMega48 with 4KB ROM and 512 bytes RAM en ends with the ATMega2560 with 256KB ROM and 8KB RAM. These devices also differ in clock speed, number of I/O devices and pins, number of timers, optional EPROM inside, and some have specialized interface hardware (like the LIN interface in the [ATTiny87/167](http://www.atmel.com/Images/Atmel-8265-8-bit-AVR-Microcontroller-tinyAVR-ATtiny87-ATtiny167_datasheet.pdf)).

> There are also 8-bit XMEGA devices (ATxmega series) and 32-bit AVR UC3 devices, but when talking about Atmel AVR, I refer to the 8-bit ATTiny and ATMega MCU's only.

All 8-bit AVR's have at least the following core components inside:
* Flash memory - for storing the program;
* RAM - for temporary data used by the program;
* CPU - for processing the instructions;
* Timer(s) - providing various timing and counting related functions;
* Clock - for providing the signals that drive the CPU, timers and I/O devices;
* CPU registers - 32 (mostly) general purpose 16-bit registers for programming;
* I/O registers - for reading from and writing to the I/O devices, including serial interfaces, timers, and CPU status;

The CPU and I/O registers are also mapped in the memory space of the AVR and can be accessed through RAM addressing or special I/O instructions. The diagram below visualizes the internal components of an 8-bit AVR. Note that these AVR's are referred to as 8-bit because they process 8-bits at a time with most instructions, but the memory addressing registers are 16-bit. For devices with more than 64KB ROM this requires special registers to address ROM beyond 64K (the RAMP registers).

![](atmel-avr-internal.jpg?cropResize=600,800)

This diagram from the ATTiny85 shows what makes an average Atmel AVR tick. I already mentioned the key components. Something to be aware of when low-level programming the AVR, is its I/O registers and memory map. Basically, the AVR has two separate memory spaces:
* Program memory (addressing the flash ROM)
* Data memory (addressing the general purpose and I/O registers, and the RAM)

![](avr_memory.png?cropResize=600,600)

The general purpose registers occupy the first 32 bytes of the data memory space. They can be addressed directly as part of an instruction or by addressing the memory location directly. The I/O registers come next and occupy the next 64 bytes of the data memory space. Some AVR models have extended I/O register space after the standard 64 bytes. After the (extended) I/O registers comes the actual SRAM starting at address 0x060 or higher. The actual start address of the RAM is defined in the AVR model specific header and should be used as base for addressing RAM.
Since the direct I/O instructions have only 5 bits in the instruction for the register address they are limited to the first 32 addresses. For higher numbered I/O registers there is a memory I/O operation needed instead, which takes up a little more time and space.

> Why bother with assembler programming, while C(++) is so much easier? There is actually a good reason to learn AVR assembler: the more you know about the inner workings of the MCU the more capable you will become in mastering the AVR. And we can start mixing C and Assembler if needed, as long as we obey a few rules elated to register and stack usage.

## AVR 8-bit MCU instructions

The 8-bit AVR MCU's have a small and efficient instruction set (up to about 130 instructions depending on the specific device) described in [this datasheet](http://www.atmel.com/images/atmel-0856-avr-instruction-set-manual.pdf), many of which are executed in one clock cycle. Most instructions are universally available on all 8-bit AVR's. There are of course device specific exceptions, related to missing (or added) features on some devices. The instruction set can be divided in:
* Branching instructions
* I/O register instructions (part of bit manipulation instructions)
* Arithmetic and logical instructions
* Bit manipulation instructions
* Memory access instructions
* MCU control instructions

A complete list can be found [here](http://www.atmel.com/images/atmel-0856-avr-instruction-set-manual.pdf) and the device specific details can be found in the datasheet of the device you're programming.

## Compact, reusable library routines

While working on a program to remotely control a dimmable LED, the need for some core functions arose, like allocating memory, reading/writing a queue, programming an EPROM, etc. To fix this once and for all, I've created a small set of routines that can be used by different programs. The complete list (for now):

| source | description |
|--------|-------------|
| [keylib](https://github.com/justClouds/avr-asmlib/tree/master/src/keylib) | Multiple buttons reading routines with debouncing |
| [queuelib](https://github.com/justClouds/avr-asmlib/tree/master/src/queuelib) | Queue reading and writing routines |
| [heaplib](https://github.com/justClouds/avr-asmlib/tree/master/src/heaplib) | Simple memory management routines |
| [errorlib](https://github.com/justClouds/avr-asmlib/tree/master/src/errorlib) | Error queing routines |
| [eepromlib](https://github.com/justClouds/avr-asmlib/tree/master/src/eepromlib) | EEPROM reading and writing routines |
| [rs485lib](https://github.com/justClouds/avr-asmlib/tree/master/src/rs485lib) | RS485 serial communications routines |
| [avr-macros](https://github.com/justClouds/avr-asmlib/tree/master/include) | Assembler macro's used in the different routines |

For some of these library routines a simple test program is also available on [GitHub](https://github.com/justClouds/avr-asmlib/tree/master/src) (more on that later). The _avr-macros_ file contains a series of macro's that make assembler programming life a little easier. This includes I/O instructions for the entire I/O address space, 16-bit register and memory manipulation, bit manipulation and multiple stack save and restore routines.

### Error queueing

Every program must be able to deal with errors. Handling errors can be complex, especially when deep down in some low level routine. How to gracefully fail and report the error back to the top level calling routine. And what about dealing with multiple errors? This is where the _errorlib_ routines help out. Error codes can be pushed on a LIFO queue and pulled, or peeked, when needed. There are some supporting routines to flush the buffer and check for overflow. The buffer size is defined by the ERROR_BUFFER_SIZE constant defined in the header file and can be changed if needed. These routines can store and retrieve multiple errors that occur during data processing (like UART send/receive). The error buffer holds up to MAX_ERR_ENTRIES of error codes.

Be aware that register 6 (R6) is used exclusively by the error buffer routines (across function calls) for holding the current head of queue position and should not be used elsewhere.

#### **errorbuf** library routines

**error_flush:** Flush the error code queue.

    INPUT:      None.
    OUTPUT:     CF=0 and R24=0: OK.
    USED REGS:  R6, R24.
    STACK SIZE: ~2 bytes total.

**error_init:** Initialize the error buffer by initializing all values to an empty state. Note that currently, initialization is the same as flushing the error buffer. R6 is holding the head of queue position.

    INPUT:      None.
    OUTPUT:     CF=0, R24=0: OK.
    USED REGS:  R24.
    STACK SIZE: ~4 bytes total, including function call.

**error_push:** Store a new entry (error code) in the error queue. No new entries are stored once the queue is full (which triggers the overflow flag). R6 is holding the current head of queue position. The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue.

    INPUT:      R24 = error code to push on error queue (LIFO).
    OUTPUT:     CF=0: succeeded;
                CF=1: queue is full (overflow flag is set too).
    USED REGS:  SREG[C].
    STACK SIZE: ~6 bytes total, including function calls.

**error_pop:** Retrieve the most current entry from the queue (LIFO) and return it. The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue. R6 is holding the current head of queue position.

    INPUT:      None.
    OUTPUT:     R24 = last pushed error code (LIFO), or 0 (OK) if no error codes in queue;
                ZF=1: no error code in queue;
                ZF=0 if error code rerieved from LIFO queue.
    USED REGS:  R24.
    STACK SIZE: ~4 bytes total, including function calls.

**error_peek:** Return the most current entry, nothing is removed from the error queue. The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue. R6 is holding the current head of queue position.

    INPUT:      None.
    OUTPUT:     R24 = last pushed error code (LIFO), or 0 (OK) if no error codes;
                ZF=1: no error code in queue;
                ZF=0 if error code rerieved from head of queue.
    USED REGS:  R24, TMPR.
    STACK SIZE: ~5 bytes total, including function calls.

**error_overflow:** Check whether too many errors have occurred. The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue.

    INPUT:      None.
    OUTPUT:     CF=0 and R24=0: No overflow;
                CF=1 and R24!=0: Error queue overflow.
    USED REGS:  R24.
    STACK SIZE: ~2 bytes total, including function calls.

### Queue Handling

One of the basic functions required in many programs is a queue function (like a serial receive buffer), where data is stored at its 'tail' and read from its 'head' simultaneously. These library routines are for FIFO/LIFO Queue reading, writing and initialization. The queue consists of a memory structure and a buffer to store the bytes stored in, or extracted from, the queue. The maximum queue buffer size is 254 bytes and the minimum size is 8 bytes. The queue reading and writing routines are interrupt proof by utilizing a lock byte to be respected by any (interrupt service) routine that wants to read or write the fifo queue.

Note: Tested on ATTiny45/85/2313 and ATMega328(P).

#### queue Library routines

**queue_init:** Set up a new FIFO/LIFO queue by initializing all values to an 'empty queue' state. The memory for the queue structure and the data buffer is dynamically allocated from heap memory. It is assumed that no ISR tries to access the Queue during initialization.

    INPUT:      R24 = Queue data buffer size (should be >=4 and <=64).
    OUTPUT:     CF=0: Succeeded;
                CF=1: Error occurred (R24 holds the error code on exit);
                Z = Address of allocated and initialized queue (if CF=0).
    USED REGS:  R24, TMPR, Z.
    STACK SIZE: ~16 bytes.

**queue_free:** Release the previously initialized queue memory (structure and data buffer). It is assumed that no ISR tries to access the FIFO Queue during/after this routine.

    INPUT:      Z (QPR)	= Address of Queue structure.
    OUTPUT:     CF=0: Succeeded;
                CF=1: Error occurred (R24 holds the error code).
    USED REGS:  R24, TMPR.
    STACK SIZE: ~12 bytes.

**queue_flush:** Reset the queue pointers and counters to 'empty queue'. Note that the lock flag is ignored (and reset) during queue flush.

    INPUT:      Z = Address of queue to flush.
    OUTPUT:     None.
    USED REGS:  TMPR.
    STACK SIZE: ~3 bytes.

**queue_put:** Put a byte in the FIFO/LIFO queue (@Z) at next free position. Any error code is returned in R24 (if the queue is full or locked) and the carry flag is set to indicate the error to the calling program. This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.

    INPUT:      Z = Address of queue structure to store read data byte; R24 = byte to store in the queue.
    OUTPUT:     CF=0: Succeeded, R24 = byte stored in queue;
                CF=1: Queue full or locked, R24 = error code.
    USED REGS:  R24 returns byte stored (CF=0) or error code (CF=1).
    STACK SIZE: ~7 bytes.

**queue_get:** Read next byte from the FIFO queue @Z. Any error code is returned in R24 (if the queue is empty	or locked) and the carry flag is set to indicate the error to the calling program. This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.

    INPUT:      Z (QPR) = Address of queue to read next data byte from.
    OUTPUT:     CF=0: Succeeded;
                CF=1: Queue emtpy or locked;
                R24 (QDR) = byte retrieved from queue, or error code (if CF=1).
    USED REGS:  R24 (QDR/QER) returns data byte or error code.
    STACK SIZE: ~7 bytes.

**queue_length:** Get # of bytes stored in queue pointed at by Z. This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.

    INPUT:      Z (QPR) = Address of queue structure to return length of data from.
    OUTPUT:     R24 (QDR) = length of queue data stored in queue.
    USED REGS:  R24.
    STACK SIZE: ~7 bytes.

### Key detection

Routines for detecting key press and release with debouncing function and key repeat detection when a key is kept pressed for a longer time. These routines support up to 8 keys. Debouncing is implemented by 4 samples of key state. These routines are based on the de-bouncing routines in C, written by Peter Dannegger.

PORTB is used for the button input pins (available on all AVR MCUs). Note that the smallest ATtiny MCUs have up to 6 I/O pins on port B (PB0-PB5), while these functions support a maximum	of 8 buttons. Trying to use I/O pins not available, or assigned other functions, produces undefined results. Connect keys as 'close to ground':

        :
        |
    PBn +-----------+
        |           |
        |         S1 /
    PBm +--..       |
        |           |
        :          GND

Note: Tested on ATTiny45/85/2313.

It is assumed that all generic initialization, like stackpointer setup is done by the calling program.

This library defines one interrupt vector (TIMER0_OVF); all other vectors are up to thecalling program. When TIMER0 is used elsewhere, you could modify the source and include it with your program.

#### Key library routines

**keys_init:** Initialize the key press library for the needed number of keys. This routine uses 27 CPU cycles, including returning to caller.

    INPUT:      R24 = key mask bit specifying the keys to 'activate';
                R25 = key repeat mask bit specifying the keys to detect repeat for.
    OUTPUT:     R24 = 0 (and CF=0): OK.
    USED REGS:  R24,R25.
    STACK SIZE: ~2 bytes.

**keys_pressed:** Check if one ore more keys have been pressed. Each pressed key is reported only once. This routine consumes 17 CPU cycles, including returning to the caller.

    INPUT:      R24 = key mask to inquire.
    OUTPUT:     R24 = key mask of pressed keys.
    USED REGS:  R24.
    STACK SIZE: ~3 bytes, including calling this routine.

**keys_repeat:** Check if one ore more keys are pressed long enough for the repeat functionality to kick in. Each pressed key is reported only once. After a small setup delay, the key is reported being	pressed in subsequent calls to this function. This simulates the user repeatedly pressing and releasing the key. This routine consumes ~18 CPU cycles, including returning to the caller.

    INPUT:      R24 = key repeat mask.
    OUTPUT:     R24 = key mask of long pressed keys.
    USED_REGS:  R24.
    STACK SIZE: ~3 bytes, including calling this routine.

**keys_state:** Check if one or more keys is pressed right now. The pressed state is not altered. This routine consumes ~11 CPU cycles, including returning to the caller.

    INPUT:      R24 = key mask defining keys to inquire.
    OUTPUT:     R24 = key mask of currently pressed keys.
    USED_REGS:  R24.
    STACK SIZE: ? bytes, including calling this routine.

**keys_short:** Check if one ore more keys is currently short pressed. Each pressed key is reported only once. This routine consumes ~xx CPU cycles, including returning to the caller.

    INPUT:      R24 = key mask for inquiry on specified keys only.
    OUTPUT:     R24 = key mask of currently (short) pressed keys.
    USED_REGS:  R24.
    STACK SIZE: ? bytes, including calling this routine.

**keys_long:** Check if one ore more keys have been long pressed. Each pressed key is reported only once. This routine consumes xx CPU cycles, including returning to the caller.

    INPUT:      R24 = key mask for inquiry on only specified keys.
    OUTPUT:     R24 = key mask of long pressed keys.
    USED_REGS:  R24.
    STACK SIZE: ? bytes, including calling this routine.

## Memory management

Simple heap memory allocation routines for small 8-bit AVR MCU's that have limited amounts of SRAM but still need some form of dynamic memory. Please note, that there is virtually no error checking and whenever memory outside the allocated block is written, the heap will get corrupted.

The maximum block size is limited to 127 bytes and the total heap size is fixed to 255 bytes.

Tested on ATTiny45/85/2313 and ATMega328(P).

### Heap management Library routines

**heap_alloc:** Allocate the specified amount of memory and return pointer to it, or CF=1 if not enough	free memory available. The first time this routine is called, the heap area is initialized as an empty (free) block of memory. It is assumed that no ISR tries to access the heap during initialization.

    INPUT:      R24 = Size of memory block to allocate.
    OUTPUT:     CF=0: Succeeded; X = address of allocated memory block;
                CF=1: Error; R24 = error code (of CF=1).
    USED_REGS:  TMPR, X ,R24 (if error).
    STACK SIZE: ~12 bytes.

**heap_free:** Free the specified memory block (X) and put it in the list of free memory blocks at the right point to make garbage collection possible. When returning the memory block to the free list, the garbage collection routine is called	to merge adjacent blocks of memory.

    INPUT:      X = Address of memory block to return to the heap.
    OUTPUT:     X = NULL.
    USED_REGS:  TMPR, X.
    STACK SIZE: ~7 bytes.

## EEPROM reading and writing

Defines constants and function prototypes for reading, writing and erasing the EEPROM memory in	8-bit AVR MCUs. It is assumed that all generic initialization, like stackpointer setup is done by the calling program.

Don't use the first byte of EEPROM amemory s it may get corrupted during power down on most AVR types.

Writing or erasing takes about 1.8ms on an ATtiny (Erase+Write ~3.6ms).

### EEPROM Library routines

**ee_init:**This routine writes 0xFF in all EEPROM Address and Data buffer locations to indicate empty slots. Set the initflag to indicate it is initialized.

    INPUT:      None.
    OUTPUT:     None.
    USED_REGS:  YL (YH also if SRAM>256 bytes).
    STACK SIZE: ? bytes, including calling this routine.

**ee_readbyte:** This routine reads one byte from EEPROM at the specified EEPROM location. First we check if the data is still in the buffer, otherwise we read from EEPROM. The MCU is halted for 4 clock cycles during EEPROM read.

    INPUT:      X(L) = EEPROM address to read.
    OUTPUT:     R24 = data byte read from EEPROM location.
    USED_REGS:  R24.
    STACK SIZE: ~6 bytes, including calling this routine.

**ee_writebyte:** This routine writes one byte to EEPROM from the specified memory location. The difference between existing byte and the new value is used to select the most efficient EEPROM programming mode. Programming the byte is controlled by the EE_RDY interrupt routine, so we won't wait until the EEPROM is ready to write the byte, but return immediately if buffer not full.

    INPUT:      X(L) = EEPROM address to write; R24 = Byte to write in EEPROM.
    OUTPUT:     None.
    USED_REGS:  None.
    STACK SIZE: ~7-8 bytes, including calling this routine.

## RS485 communications

Routines for RS485 Master and Slave Library routines (for 8-bit AVR MCU with hardware USART). Implements a simple RS485-based communications protocol. This Library supports up to 127 slaves on a single RS485 bus to communicate in master/slave style.

RS485 is a half duplex differential serial bus and all communication is following the 'Request followed by Response' pattern from Master to Slave (except for Broadcast messages that are never answered by a Response message from a Slave).

The frame format is fixed at 9N1: 1 start bit, 9 data bits, no parity and 1 stop bit. The 9h bit is never used (0)by the Slaves. The Master makes use of it (making it 1) to indicate an address byte is being sent. All other data is sent by the Master with the 9th bit set to zero (0). This is to support the AVR Multi-Processor Communication Mode (MPCM) whereby the USART in the Slaves ignore any frame except address bytes with the 9th bit set. If it is the Slaves address, it will start receiving the other bytes until all frames of a message are received; then it will switch back to MPCM mode waiting for an address frame. The MPCM mode frees the Slaves from filtering data bytes not meant for them, so they can spent their time on more important tasks.

Currently only the ATtiny2313(A) MCU devices are supported/tested with this library. Besides the USART of the ATtiny2313(A), the port pin PD3 (can be redefined at Library compile time) is used to switch directions on the RS485 transceiver. PD0 (RXD)and PD1 (TXD) are used by the USART as Receive and Transmit lines.

The RS485 library supports two types of messages: Request & Response.

_REQUEST MESSAGES:_

Request messages do have the following structure, where the number of data bytes is currently limited to eight. You can change that limit by adapting the definition of NB_PARAM_BYTES. You can adapt the library to your application by setting an application specific value for NB_PARAM_BYTES in your makefile. Don't change anything if you can live with eight bytes.

    +----+
    |  0 | - Address (0-128)
    +----+
    |  1 | - Command (0-255)
    +----+
    |  2 | - Number of parameters (0-8)
    +----+
    |  3 | - First parameter (0-255)
    +----+
    |  4 | - Second parameter (0-255)
    +----+
    |    |
      ...
    |    |
    +----+
    | 10 | - Eigth parameter (0-255)
    +----+

Please note that the address byte has the following structure:

    +----+----+----+----+----+----+----+----+
    |RESP|ADR6|ADR5|ADR4|ADR3|ADR2|ADR1|ADR0|
    +----+----+----+----+----+----+----+----+
    MSB                                   LSB

Seven bits (ADR0->ADR6) are used to encode the address of the Slave.
The high bit (RESP) is used to indicate if a response by the Slave is required.
RESP=1 means "Response required", RESP=0 means "don't send Response".
The broadcast message uses address zero (0).
The RESP bit is zero there, hence no response is expected which is the expected behavior for broadcast.

RESP cannot be set in case of broadcast address.

_RESPONSE MESSAGES:_

Response messages do have the following structure, where the number of data bytes currently is limited to 8. You can change that limit by adapting the definition of NB_RET_BYTES. You can adapt the library to your application by setting an application specific value for NB_RET_BYTES in your makefile. Don't change anything if you can live with eight bytes.

    +----+
    |  0 | - Number of return values (0-8)
    +----+
    |  1 | - First return value (0-255)
    +----+
    |  3 | - Second return value (0-255)
    +----+
    |    |
     ...
    |    |
    +----+
    |  8 | - Eighth return value (0-255)
    +----+

Used Makefile entries/defines:

| Name | Explanation | Default  |
|------|-------------|----------|
| F_CPU | Clock frequency in Hz. | 8000000 |
| BAUD | Baud rate, typical baud rates are 9600, 19200, 38400. Not all baud rates can be produced depending on the given MCU clock. Use a baud crystal (e.g. 14.7456 MHz) to produce all standard baud rates with no error. The compiler will issue a warning in case CPU clock and baud rate do not match (error rate to high). | 38400 |
|RS485_SWITCHING_DELAY | Delay in ms. Short delay will be performed after receiving the last byte from the request and switching the Slave bus transceiver to send mode. | 5 |

_EXAMPLE:_

Example usage of the Slave library routines:

    #include "RS485Lib.h"
    //...Initialize MCU hardware (except USART)...
    rs485Initialize(Slave address);
    while (TRUE)
    {
        if (rs485MessageAvailable())
        {
            rs485Message* pRequest;
            rs485ConsumeRequest(pRequest);
            //....Do the requested processing...
            if (isResponseRequired(&pRequest))
            {
                // Only for request & response messages (non-broadcast) with RESP=1
                rs485Message* pResponse;
                //...Populate the response message...
                rs485Respond(pResponse);
            }
        }
        //... Do other (non RS485 related) things, but don't get stuck in an infinite loop...
    }

### RS485 Library routines

NOTE: The ZEROR is assumed to be initialized with zero (0) in most of these routines.

**RS485_set_direction:** This routine set the UART, Interrupt flags and RS485 transceiver to either Transmit mode or Receive mode, specified by input parameter register R24. If R24 == 0, we switch to Transmit Mode, and if R24 !=0 we switch to Receive Mode. The State (STATR) is not changed by this routine; that's up to the caller. This routine counts 10-21 CPU cycles, including returning to calling routine,

    INPUT:      R24 = Transmit (0) or Receive Mode (!0).
    OUTPUT:     None.
    USED REGS:  None.
    STACK SIZE: ? bytes (including calling this routine).

**RS485_message_init:** Initialize the static/control variables in the RS485 message buffer, but don't touch the message body. The message size is fixed at 16 bytes. This routine counts 25-34 CPU cycles, including returning to calling routine.

    INPUT:      Z = Address of RS485 message to initialize;
                R24 = Slave or Broadcast address to store in message.
    OUTPUT:     Z = address of initialized RS485 message.
    USED REGS:  R24.
    STACK SIZE: ~4 bytes (including calling this routine).

**RS485_message_flush:** Flush the message data and reset the index variables in the message structure. The message size is currently fixed at 16 bytes. The UART receive buffer is flushed too.

    INPUT:      Z = Address of RS485 message to flush.
    OUTPUT:     Z = address of flushed RS485 message.
    USED REGS:  R24.
    STACK SIZE: ? bytes (including calling this routine).

**RS485_init:** Initialize UART and variables for RS485 Master or Slave mode. The message size is fixed at 16 bytes. The passed RS485 receive message buffer is flushed and initialized with starting values. The Frame format is set at 1 start, 9 data bits (MPM mode), no parity, 2 stop bits. The Baud rate is defined by the BAUD makefile variable.

    INPUT:      Z = Address of RS485 message buffer to use for receiving messages;
                R24 = Slave address, or 0x00 if Master mode.
    OUTPUT:     Z = Address of initialized RS485 receive message;
                STATR = Request message state of RS485 library (STATE_REQUEST).
    USED REGS:  R24,R25,STATR.
    STACK SIZE: ~11 bytes (including calling this routine).

**RS485_busy:** Check if RS485 interface is busy transmitting or receiving. This routine uses 9-12 CPU cycles, including returning to calling routine.

    INPUT:      None.
    OUTPUT:     CF=0: No transmit or receive busy;
                CF=1: A transmit or receive is currently busy.
    USED REGS:  R24.
    STACK SIZE: ~2 bytes.

**RS485_message_available:** Check if a received message is waiting to be processed. This routine uses 9 CPU cycles, including returning to the calling routine.

    INPUT:      None.
    OUTPUT:     CF=0: No message available;
                CF=1: message waiting to be processed.
    USED REGS:  None.
    STACK SIZE: ~2 bytes (for return adddress).

**RS485_consume:** Get the received message to process. The calling program should have called rs485_message_available first to check if a message is available to consume.

    INPUT:      None.
    OUTPUT:     CF=0: OK, message to process @Z;
                CF=1: Error.
    USED REGS:  R24,Z.
    STACK SIZE: ~10 bytes.

**RS485_send_message:** Send a message to the Master or Slave. The CRC16 value is calculated and stored in the RS485 message structure.

    INPUT:      Z = Address of RS485 message to transmit.
    OUTPUT:     None.
    USED REGS:  R24.
    STACK SIZE: ~8 bytes.

**RS485_response_expected:** Check if a Response message is expected. This routine tests if the 8th bit of the slave address is set in the message buffer. This routine uses 9 CPU cycles on ATtiny, including returning to the calling routine.

    INPUT:      Z = Points at message to check.
    OUTPUT:     CF=0: No response expected;
                CF=1: Response expected.
    USED REGS:  R24.
    STACK SIZE: ~2 bytes (including rcall to this routine).
