# AVR-ASMLIB

Various Atmel AVR 8-bt MCU Assembler library routines.

This code comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under certain conditions. The program and its source code are published under the [GNU General Public License](http://www.gnu.org/licenses/gpl-3.0.txt) (GPL).

## keylib

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

### Version history

v0.4    Small update to adapt to PlatformIO.
v0.3    Removed SFR_OFFSET fix.
v0.2    Fixed wrong pin direction for keys (worked for a while with key at output port).
v0.1    Initial version.

### Library routines

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

## queuelib

Routines for FIFO/LIFO Queue reading, writing and initialization. The queue consists of a memory structure and a buffer to store the bytes stored in, or extracted from, the queue.
The maximum queue buffer size is 254 bytes and the minimum size is 8 bytes.
The queue reading and writing routines are interrupt proof by utilizing a lock byte to be respected by any (interrupt service) routine that wants to read or write the fifo queue.

Tested on ATTiny45/85/2313 and ATMega328(P).

### Version history

v0.4    Added dynamic memory allocation functions for buffer/queue allocation.
v0.3    Added LIFO function for error queueing functions.
v0.2    Changed to library.
v0.1    Initial test version.

### Library routines

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
