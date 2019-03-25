# AVR-ASMLIB Library routines

Various Atmel AVR 8-bt MCU Assembler library routines.

This code comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under certain conditions. The program and its source code are published under the [GNU General Public License](http://www.gnu.org/licenses/gpl-3.0.txt) (GPL).

## **key** Library

Routines for detecting key press and release with debouncing function and key repeat detection when a key is kept pressed for a longer time. These routines support up to 8 keys. Debouncing is implemented by 4 samples of key state.
These routines are based on the de-bouncing routines in C, written by Peter Dannegger.

PORTB is used for the button input pins (available on all AVR MCUs). Note that the smallest ATtiny MCUs have up to 6 I/O pins on port B (PB0-PB5), while these functions support a maximum	of 8 buttons. Trying to use I/O pins not available, or assigned other functions, produces undefined results.
Connect keys as 'close to ground':

        :
        |
    PBn +-----------+
        |           |
        |         S1 /
    PBm +--..       |
        |           |
        :          GND

Tested on ATTiny45/85/2313.

It is assumed that all generic initialization, like stackpointer setup is done by the calling program.

This library defines one interrupt vector (TIMER0_OVF); all other vectors are up to thecalling program. When TIMER0 is used elsewhere, you could modify the source and include it with your program.

### **key** Version history

v0.4    Small update to adapt to PlatformIO.

v0.3    Removed SFR_OFFSET fix.

v0.2    Fixed wrong pin direction for keys (worked for a while with key at output port).

v0.1    Initial version.

### **key** Library routines

**keys_init**
Initialize the key press library for the needed number of keys.
This routine uses 27 CPU cycles, including returning to caller.

_INPUT:_        R24 = key mask bit specifying the keys to 'activate'.
                R25 = key repeat mask bit specifying the keys to detect repeat for.

_OUTPUT:_       R24 = 0 (and CF=0): OK.

_USED REGS:_    R24,R25.

_STACK SIZE:_   2 bytes.

**keys_pressed**
Check if one ore more keys have been pressed. Each pressed key is reported only once.
This routine consumes 17 CPU cycles, including returning to the caller.

_INPUT:_        R24 = key mask to inquire.

_OUTPUT:_       R24 = key mask of pressed keys.

_USED REGS_:    R24.

_STACK SIZE_:   3 bytes, including calling this routine.

**keys_repeat**
Check if one ore more keys are pressed long enough for the repeat functionality to kick in. Each pressed key is reported only once. After a small setup delay, the key is reported being	pressed in subsequent calls to this function. This simulates the user repeatedly pressing and releasing the key.
This routine consumes ~18 CPU cycles, including returning to the caller.

_INPUT:_        R24 = key repeat mask.

_OUTPUT_:       R24 = key mask of long pressed keys.

_USED REGS:_    R24.

_STACK SIZE_:   3 bytes, including calling this routine.

**keys_state**
Check if one or more keys is pressed right now. The pressed state is not altered.
This routine consumes ~11 CPU cycles, including returning to the caller.

_INPUT_:        R24 = key mask defining keys to inquire.

_OUTPUT_:       R24 = key mask of currently pressed keys.

_USED REGS:_    R24.

_STACK SIZE:_   ? bytes, including calling this routine.

**keys_short**
Check if one ore more keys is currently short pressed. Each pressed key is reported only once.
This routine consumes ~xx CPU cycles, including returning to the caller.

_INPUT:_        R24 = key mask for inquiry on specified keys only.

_OUTPUT:_       R24 = key mask of currently (short) pressed keys.

_USED REGS:_    R24.

_STACK SIZE:_   ? bytes, including calling this routine.

**keys_long**
Check if one ore more keys have been long pressed. Each pressed key is reported only once.
This routine consumes xx CPU cycles, including returning to the caller.

_INPUT:_        R24 = key mask for inquiry on only specified keys.

_OUTPUT:_       R24 = key mask of long pressed keys.

_USED REGS:_    R24.

_STACK SIZE:_   ? bytes, including calling this routine.

## **queue** Library

Routines for FIFO/LIFO Queue reading, writing and initialization. The queue consists of a memory structure and a buffer to store the bytes stored in, or extracted from, the queue.
The maximum queue buffer size is 254 bytes and the minimum size is 8 bytes.
The queue reading and writing routines are interrupt proof by utilizing a lock byte to be respected by any (interrupt service) routine that wants to read or write the fifo queue.

Tested on ATTiny45/85/2313 and ATMega328(P).

### **queue** Version history

v0.4    Added dynamic memory allocation functions for buffer/queue allocation.

v0.3    Added LIFO function for error queueing functions.

v0.2    Changed to library.

v0.1    Initial test version.

### **queue** Library routines

**queue_init**
Set up a new FIFO/LIFO queue by initializing all values to an 'empty queue' state. The memory for the queue structure and the data buffer is dynamically allocated from heap memory.
It is assumed that no ISR tries to access the Queue during initialization.

_INPUT:_        R24	= Queue data buffer size (should be >=4 and <=64).

_OUTPUT:_       CF=0: Succeeded; CF=1: Error occurred (R24 holds the error code on exit);
                Z = Address of allocated and initialized queue (if CF=0).

_USED REGS:_    R24, TMPR, Z.

_STACK SIZE:_   ~16 bytes.

**queue_free**
Release the previously initialized queue memory (structure and data buffer).
It is assumed that no ISR tries to access the FIFO Queue during/after this routine.

_INPUT:_        Z (QPR)	= Address of Queue structure.

_OUTPUT:_       CF=0: Succeeded; CF=1: Error occurred (R24 holds the error code).

_USED REGS:_    R24, TMPR.

_STACK SIZE:_   ~12 bytes.

**queue_flush**
Reset the queue pointers and counters to 'empty queue'.
Note that the lock flag is ignored (and reset) during queue flush.

_INPUT:_        Z = Address of queue to flush.

_OUTPUT:_       None.

_USED REGS:_    TMPR.

_STACK SIZE:_   ~3 bytes.

**queue_put**
Put a byte in the FIFO/LIFO queue (@Z) at next free position. Any error code is returned in R24 (if the queue is full or locked) and the carry flag is set to indicate the error to the calling program.
This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.

_INPUT:_        Z = Address of queue structure to store read data byte;
                R24 = byte to store in the queue.

_OUTPUT:_       CF=0: Succeeded, R24 = byte stored in queue;
                CF=1: Queue full or locked, R24 = error code.

_USED REGS:_    R24 returns byte stored (CF=0) or error code (CF=1).

_STACK SIZE:_   ~7 bytes.

**queue_get**
Read next byte from the FIFO queue @Z. Any error code is returned in R24 (if the queue is empty	or locked) and the carry flag is set to indicate the error to the calling program.
This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.

_INPUT:_        Z (QPR) = Address of queue to read next data byte from.

_OUTPUT:_       CF=0: Succeeded; CF=1: Queue emtpy or locked;
                R24 (QDR) = byte retrieved from queue, or error code (if CF=1).

_USED REGS:_    R24 (QDR/QER) returns data byte or error code.

_STACK SIZE:_   ~7 bytes.

**queue_length**
Get # of bytes stored in queue pointed at by Z.
This routine is ISR-proof and only disables interrupts while needed to (un)lock the queue.

_INPUT:_        Z (QPR) = Address of queue structure to return length of data from.

_OUTPUT:_       R24 (QDR) = length of queue data stored in queue.

_USED REGS:_    R24.

_STACK SIZE:_   ~7 bytes.

## **heap** Library

Simple heap memory allocation routines for small 8-bit AVR MCU's that have limited amounts of SRAM but still need some form of dynamic memory.
Please note, that there is virtually no error checking and whenever memory outside the allocated block is written, the heap will get corrupted.

The maximum block size is limited to 127 bytes and the total heap size is fixed to 255 bytes.

Tested on ATTiny45/85/2313 and ATMega328(P).

### **heap** Version history

v0.1    Initial version.

### **heap** Library routines

**heap_alloc**
Allocate the specified amount of memory and return pointer to it, or CF=1 if not enough	free memory available.
The first time this routine is called, the heap area is initialized as an empty (free) block of memory.
It is assumed that no ISR tries to access the heap during initialization.

_INPUT:_        R24 = Size of memory block to allocate.

_OUTPUT:_       CF=0: Succeeded; CF=1: Error;
                R24 = error code (of CF=1);
                X = address of allocated memory block.

_USED REGS:_    TMPR, X ,R24 (if error).
_STACK SIZE:_   ~12 bytes.
;*	This function is only for internal use from the heap_alloc routine.

**heap_free**
Free the specified memory block (X) and put it in the list of free memory blocks at the right point to make garbage collection possible.
When returning the memory block to the free list, the garbage collection routine is called	to merge adjacent blocks of memory.

_INPUT:_        X = Address of memory block to return to the heap.

_OUTPUT:_       X = NULL.

_USED REGS:_    TMPR, X.

_STACK SIZE:_   ~7 bytes.

## **eeprom** Library

Defines constants and function prototypes for reading, writing and erasing the EEPROM memory in	8-bit AVR MCUs. It is assumed that all generic initialization, like stackpointer setup is done by the calling program.

Don't use the first byte of EEPROM amemory s it may get corrupted during power down on most AVR types.

Writing or erasing takes about 1.8ms on an ATtiny (Erase+Write ~3.6ms).

### **eeprom** Version history

v0.1    Initial version.

### **eeprom** Library routines

**ee_init**
This routine writes 0xFF in all EEPROM Address and Data buffer locations to indicate empty slots. Set the initflag to indicate it is initialized.

_INPUT:_        None.

_OUTPUT:_       None.

_USED REGS:_    YL (YH if SRAM>256 bytes).

_STACK SIZE:_   ~? bytes, including calling this routine.

**ee_readbyte**
This routine reads one byte from EEPROM at the specified EEPROM location. First we check if the data is still in the buffer, otherwise we read from EEPROM.
The MCU is halted for 4 clock cycles during EEPROM read.

_INPUT:_        X(L) = EEPROM address to read.

_OUTPUT:_       R24 = data byte read from EEPROM location.

_USED REGS:_    R24.

_STACK SIZE:_   ~6 bytes, including calling this routine.

**ee_writebyte**
This routine writes one byte to EEPROM from the specified memory location. The difference between existing byte and the new value is used to select the most efficient EEPROM programming mode.
Programming the byte is controlled by the EE_RDY interrupt routine, so we won't wait until the EEPROM is ready to write the byte, but return immediately if buffer not full.

_INPUT:_        X(L) = EEPROM address to write;
                R24 = Byte to write in EEPROM.

_OUTPUT:_       None.

_USED REGS:_    None.

_STACK SIZE:_   7-8 bytes, including calling this routine.

## **errorbuf** library

Routines for error buffer writing and reading to store and retrieve multiple errors that occur during data processing (like UART send/receive). The error buffer holds up to MAX_ERR_ENTRIES of error codes.

Register 6 is used exclusively by the error buffer routines for holding the current head of queue position and should not be used elsewhere.

### **errorbuf** Version history

v0.2    Changed to assembler and library module.
v0.1    Initial version.

### **errorbuf** Library routines

**error_flush**
Flush the error code queue.

_INPUT:_        None.

_OUTPUT:_       CF=0 and R24=0: OK.

_USED REGS:_    R6, R24.

_STACK SIZE:_   ~2 bytes total.

**error_init**
Initialize the error buffer by initializing all values to an empty state.
Note that currently, initialization is the same as flushing the error buffer.
R6 is holding the head of queue position.

_INPUT:_        None.

_OUTPUT:_       CF=0, R24=0: OK.

_USED REGS:_    R24.

_STACK SIZE:_   ~4 bytes total, including function call.

**error_push**
Store a new entry (error code) in the error queue. No new entries are stored once the queue is full (which triggers the overflow flag). R6 is holding the current head of queue position.
The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue.

_INPUT:_        R24 = error code to push on error queue (LIFO).

_OUTPUT:_       CF=0: succeeded;
                CF=1: queue is full (overflow flag is set too).

_USED REGS:_    SREG[C].

_STACK SIZE:_   ~6 bytes total, including function calls.

**error_pop**
Retrieve the most current entry from the queue (LIFO) and return it. The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue.
R6 is holding the current head of queue position.

_INPUT:_        None.

_OUTPUT:_       R24 = last pushed error code (LIFO), or 0 (OK) if no error codes in queue;
                Z=1: no error code in queue, Z=0 if error code rerieved from LIFO queue.

_USED REGS:_    R24.

_STACK SIZE:_   ~4 bytes total, including function calls.

**error_peek**
Return the most current entry, nothing is removed from the error queue.
The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue.
R6 is holding the current head of queue position.

_INPUT:_        None.

_OUTPUT:_       R24 = last pushed error code (LIFO), or 0 (OK) if no error codes;
                Z=1: no error code in queue, Z=0 if error code rerieved from head of queue.

_USED REGS:_    R24, TMPR.

_STACK SIZE:_   ~5 bytes total, including function calls.

**error_overflow**
Check whether too many errors have occurred.
The queue can be used in interrupt routines, because interrupts are disabled during queue manipulation to prevent corruption of the queue.

_INPUT:_        None.

_OUTPUT:_       CF=0 and R24=0: No overflow;
                CF=1 and r24!=0: Error queue overflow.

_USED REGS:_    R24.

_STACK SIZE:_   ~2 bytes total, including function calls.

## **rs485** Library

Routines for RS485 Master and Slave Library routines (for 8-bit AVR MCU with hardware USART). Implements a simple RS485-based communications protocol. This Library supports up to 127 slaves on a single RS485 bus to communicate in master/slave style.

RS485 is a half duplex differential serial bus and all communication is following the 'Request followed by Response' pattern from Master to Slave (except for Broadcast messages that are never answered by a Response message from a Slave).

The frame format is fixed at 9N1: 1 start bit, 9 data bits, no parity and 1 stop bit.
The 9h bit is never used (0) by the Slaves. The Master makes use of it (making it 1) to indicate an address byte is being sent. All other data is sent by the Master with the 9th bit set to zero (0). This is to support the AVR Multi-Processor Communication Mode (MPCM) whereby the USART in the Slaves ignore any frame except address bytes with the 9th bit set. If it is the Slaves address, it will start receiving the other bytes until all frames of a message are received; then it will switch back to MPCM mode waiting for an address frame.
The MPCM mode frees the Slaves from filtering data bytes not meant for them, so they can spent their time on more important tasks.

Currently only the ATtiny2313(A) MCU devices are supported/tested with this library. Besides the USART of the ATtiny2313(A), the port pin PD3 (can be redefined at Library compile time) is used to switch directions on the RS485 transceiver. PD0 (RXD)and PD1 (TXD) are used by the USART as Receive and Transmit lines.

The RS485 library supports two types of messages: Request & Response.

_REQUEST MESSAGES:_

Request messages do have the following structure, where the number of data bytes is currently limited to eight. You can change that limit by adapting the definition of NB_PARAM_BYTES.
You can adapt the library to your application by setting an application specific value for NB_PARAM_BYTES in your makefile. Don't change anything if you can live with eight bytes.

  +----+
  |  0 | - Address (0-128)
  +----+
  |  1 | - Command (0-255)
  +----+
  |  2 | - Number of parameters (0-8)
  +----+
  |  3 | - First parameter (0-255)
  +----+
  |  3 | - Second parameter (0-255)
  +----+
  |    |
   ...
  |    |
  +----+
  | 10 | - Eighth parameter (0-255)
  +----+

Please note that the address byte has the following structure:
    +----+----+----+----+----+----+----+----+
    |RESP|ADR6|ADR5|ADR4|ADR3|ADR2|ADR1|ADR0|
    +----+----+----+----+----+----+----+----+
   MSB                                LSB

- Seven bits (ADR0->ADR6) are used to encode the address of the Slave.
- The high bit (RESP) is used to indicate if a response by the Slave is required.
- RESP=1 means "Response required", RESP=0 means "don't send Response".
- The broadcast message uses address zero (0).
- The RESP bit is zero there, hence no response is expected which is the expected behavior for broadcast.
- RESP cannot be set in case of broadcast address.

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

Name | Explanation | Default value
-----+-------------+---------------
F_CPU | Clock frequency in Hz. | 8000000
BAUD | Baud rate, typical baud rates are 9600, 19200, 38400. Not all baud rates can be produced depending on the given MCU clock. Use a baud crystal (e.g. 14.7456 MHz) to produce all standard baud rates with no error. The compiler will issue a warning in case CPU clock and baud rate do not match (error rate to high). | 38400
RS485_SWITCHING_DELAY | Delay in ms. Short delay will be performed after receiving the last byte from the request and switching the Slave bus transceiver to send mode.

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

### **rs485** Version history

v0.2    Removed SFR_OFFSET define.

v0.1    Initial version.

### **rs485** Library routines

The ZEROR is assumed to be initialized with zero (0) in most of these routines.

**RS485_set_direction**
This routine set the UART, Interrupt flags and RS485 transceiver to either Transmit mode or Receive mode, specified by input parameter register R24. If R24 == 0, we switch to Transmit Mode, and if R24 !=0 we switch to Receive Mode.
The State (STATR) is not changed by this routine; that's up to the caller.
This routine counts 10-21 CPU cycles, including returning to calling routine,

_INPUT:_        R24 = Transmit (0) or Receive Mode (!0).

_OUTPUT:_       None.

_USED REGS:_    None.

_STACK SIZE:_   ~? bytes (including calling this routine).

**RS485_message_init**
Initialize the static/control variables in the RS485 message buffer, but don't touch the message body. The message size is fixed at 16 bytes.
This routine counts 25-34 CPU cycles, including returning to calling routine.

_INPUT:_        Z = Address of RS485 message to initialize;
                R24 = Slave or Broadcast address to store in message.

_OUTPUT:_       Z = address of initialized RS485 message.

_USED REGS:_    R24.

_STACK SIZE:_   ~4 bytes (including calling this routine).

**RS485_message_flush**
Flush the message data and reset the index variables in the message structure. The message size is currently fixed at 16 bytes.
The UART receive buffer is flushed too.

_INPUT:_        Z = Address of RS485 message to flush.

_OUTPUT:_       Z = address of flushed RS485 message.

_USED REGS:_    R24.

_STACK SIZE:_   ~X bytes (including calling this routine).

**RS485_init**
Initialize UART and variables for RS485 Master or Slave mode. The message size is fixed at 16 bytes.
The passed RS485 receive message buffer is flushed and initialized with starting values.
The Frame format is set at 1 start, 9 data bits (MPM mode), no parity, 2 stop bits.
The Baud rate is defined by the BAUD makefile variable.

_INPUT:_        Z = Address of RS485 message buffer to use for receiving messages;
                R24 = Slave address, or 0x00 if Master mode.

_OUTPUT:_       Z = Address of initialized RS485 receive message;
                STATR = Request message state of RS485 library (STATE_REQUEST).

_USED REGS:_    R24,R25,STATR.

_STACK SIZE:_   ~11 bytes (including calling this routine).

**RS485_busy**
Check if RS485 interface is busy transmitting or receiving.
This routine uses 9-12 CPU cycles, including returning to calling routine.

_INPUT:_        None.

_OUTPUT:_       CF=0: No transmit or receive busy;
                CF=1: A transmit or receive is currently busy.

_USED REGS:_     R24.

_STACK SIZE:_   ~2 bytes.

**RS485_message_available**
Check if a received message is waiting to be processed.
This routine uses 9 CPU cycles, including returning to the calling routine.

_INPUT:_        None.

_OUTPUT:_       CF=0: No message available;
                CF=1: message waiting to be processed.

_USED REGS:_    None.

_STACK SIZE:_   ~2 bytes (for return adddress).

**RS485_consume**
Get the received message to process.
The calling program should have called rs485_message_available first to check if a message is available to consume.

_INPUT:_        None.

_OUTPUT:_       CF=0: OK, message to process @Z;
                CF=1: Error.

_USED REGS:_    R24,Z.

_STACK SIZE:_   ~10 bytes.

**RS485_send_message**
Send a message to the Master or Slave.
The CRC16 value is calculated and stored in the RS485 message structure.

_INPUT:_        Z = Address of RS485 message to transmit.

_OUTPUT:_       None.

_USED REGS:_    R24.

_STACK SIZE:_   ~8 bytes.

**RS485_response_expected**
Check if a Response message is expected. This routine tests if the 8th bit of the slave address is set in the message buffer.
This routine uses 9 CPU cycles on ATtiny, including returning to the calling routine.

_INPUT:_        Z = Points at message to check.

_OUTPUT:_       CF=0: No response expected;
                CF=1: Response expected.

_USED REGS:_    R24.

_STACK SIZE:_   ~2 bytes (including rcall to this routine).
