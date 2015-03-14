/*
* Snake_1.asm

*

*  Created: 2012-04-24 13:18:11

*   Author: Viktor Öberg

*/

//-------------------------
//			NOTES
//-------------------------
;	Direction of the snake is determined by reading from the rDirectionFlag register
;	0b00000001 = up
;	0b00000010 = down
;	0b00000100 = left
;	0b00001000 = right
;	
;	When the timer-interrupt happens, rUpdateFlag is set to
;	0b00000001
;	This in turn will make the program enter the update subroutine
;	In here, input from the joystick is read, which in turn sets the rDirectionFlag
;
;	Also, the game logic will be in this subroutine
;	Depending on the rDirectionFlag, the snake will "move" in the direction currently
;	set by the rDirectionFlag
;	
;	Also adds a segment to the snake if it eats
;
;	Finally reseting the rUpdateFlag, making the program wait for
;	the next interrupt to once again update the snake in memory.
//-------------------------
//			ENDNOTES
//-------------------------



.DEF rUpdateFlag = r20
.DEF rDirectionFlag = r21
.DEF rUpdateDelay = r22
.DEF rRowOffset = r24
.DEF rCurrentByte = r25

.dseg

	//---------------
	// Five matrices
	//---------------
	; First one: byte 0-8, Where the drawsubroutine gets its information.
	; Second: byte 9-16, Position of the "head" of the snake ( the part that is moving )
	; Third: byte 17-24, The body of the snake
	; Fourth: byte 25-32, The "tail"-bit of the snake ( the bit to clear )
	; Fifth: byte 33-40, The food. 
	
	matrix: .byte 40  



.cseg /* Code segment */


.org 0x0000

	jmp init

.org 0x0020
    jmp tick

   
init:
	// Init directionflag to zero (temp)
	ldi rDirectionFlag, 0b00000000
	ldi rRowOffset, 0b00000011
	ldi rUpdateDelay, 0b00000000
	ldi rCurrentByte, 0b00000000
	ldi r23, 0b00000000

	//ldi r23, 0b00000010
	
	
	//ldi r25, 0b00000001

    	//-----------------------------------------------
    	//	Init Data Direction Registers
    	//	Sets the ports to be output (1) or input (0)
    	//-----------------------------------------------

    	//	Port C [0, 1, 2, 3] Out, C [4, 5] In
		
    	ldi r16, 0b00001111
   	 out DDRC, r16

    	//	Port D [2, 3, 4, 5, 6, 7] Out
   	 ldi r16, 0b11111100
   	 out DDRD, r16

    	//	Port B [0, 1, 2, 3, 4, 5] Out
   	 ldi r16, 0b00111111
   	 out DDRB, r16  	 

    	//----------------------
    	//	Init A/D Converter
    	//----------------------
    	//	1. Sätt bit 6 (REFS0) i ADMUX till 1 och bit 7 (REFS1) till 0.
    	//	2. Sätt bit 0 – 2 (ADPS0, ADPS1, ADPS2) samt bit 7 (ADEN) i ADCSRA till 1
   	 ldi    r16, 0b01100000
   	 sts ADMUX,r16
   	 ldi r16,0b10000111
   	 sts ADCSRA,r16
  	 
    	//-----------------------------------
    	//	Set A/D converter to 8-bit mode
    	//-----------------------------------   
    	//	För att ställa in A/D-omvandlaren i 8-bitarsläge skall bit 5 (ADLAR) i ADMUX-registret sättas till 1 (tänk på att inte ändra övriga bitar)


		//-----------------------------------
    	//	Global interrupt enable
    	//-----------------------------------  
   	 SEI
	 	//-----------------------------------
    	//	Init stack ( interrupt return adress)
    	//-----------------------------------  

		ldi r16,HIGH(RAMEND)
		out SPH,r16
		ldi r16,LOW(RAMEND)
		out SPL,r16

   		//-----------------------------------
    	//	Init timer
    	//-----------------------------------   
   	 ldi r16, 0b00000101
   	 lds    r17,TCCR0B
   	 or    r17,r16
   	 sts 0x45,r17

   	 ldi r16, (1<<TOIE0)
   	 lds    r17,TIMSK0
   	 or    r17,r16
   	 sts 0x6E,r17



    	//--------------------------------
    	//	Load the adress of our matrix
    	//--------------------------------
  	 
    	//	Load the high part of the adress to Y-High
    	ldi YH, HIGH(matrix)
    	//	Load the low part of the adress to Y-Low
    	ldi YL, LOW(matrix)

    	//---------------------
    	//	Load test pattern
    	//
    	//	1 0 1 0 1 1 0 0
    	//	1 1 1 0 1 0 0 0
    	//	1 0 1 0 1 1 0 0
    	//	0 0 0 0 0 0 0 0
    	//	1 0 0 0 1 1 0 0
    	//	1 0 0 0 1 0 1 0
    	//	1 0 0 0 1 1 0 0
    	//	1 1 1 0 1 0 0 0
    	//
    	//---------------------
		
  		ldi r16, 0b00000000
		std	Y+1, r16
		ldi r16, 0b00000000
		std	Y+2, r16
		ldi r16, 0b00100000
		std	Y+3, r16
		ldi r16, 0b00000000
		std	Y+4, r16
		std	Y+5, r16
		std	Y+6, r16
		std	Y+7, r16
		std	Y+8, r16

gameloop:
	
    adconversion:
		
    drawloop:
   
	// ---------------------
	//
	//    	First row  	 
	//
	// ---------------------
    	//	Activate the row bit for this row (C0)
    	sbi	PORTC,0
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+1
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit:

   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
   	 cbi PORTC,0
   	 
    // ---------------------
	//
	//    	Second row  	 
	//
	// ---------------------
    
    	//	Activate the row bit for this row (C0)
    	sbi	PORTC,1
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+2
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit2
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit2:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit2
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit2:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit2
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit2:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit2
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit2:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit2
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit2:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit2
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit2:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit2
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit2:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit2
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit2:
    
   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
    cbi PORTC,1
    
    
       	// ---------------------
	//
	//    	Third row  	 
	//
	// ---------------------
    	//	Activate the row bit for this row (C0)
    	sbi	PORTC,2
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+3
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit3
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit3:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit3
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit3:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit3
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit3:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit3
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit3:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit3
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit3:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit3
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit3:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit3
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit3:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit3
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit3:
    
   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
    cbi PORTC,2
    
    	// ---------------------
	//
	//    	Fourth row  	 
	//
	// ---------------------
    	//	Activate the row bit for this row (C0)
    	sbi	PORTC,3
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+4
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit4
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit4:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit4
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit4:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit4
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit4:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit4
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit4:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit4
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit4:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit4
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit4:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit4
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit4:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit4
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit4:
    
   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
    cbi PORTC,3
	// ---------------------
	//
	//    	Fifth row  	 
	//
	// ---------------------
    	//	Activate the row bit for this row (C0)
    	sbi	PORTD,2
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+5
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit5
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit5:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit5
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit5:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit5
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit5:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit5
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit5:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit5
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit5:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit5
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit5:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit5
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit5:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit5
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit5:
    
   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
    cbi PORTD,2
    
    	// ---------------------
	//
	//    	Sixth row  	 
	//
	// ---------------------
    	//	Activate the row bit for this row (C0)
    	sbi	PORTD,3
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+6
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit6
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit6:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit6
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit6:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit6
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit6:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit6
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit6:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit6
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit6:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit6
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit6:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit6
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit6:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit6
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit6:
    
   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
    cbi PORTD,3
    	// ---------------------
	//
	//    	Seventh row  	 
	//
	// ---------------------
    	//	Activate the row bit for this row (C0)
    	sbi	PORTD,4
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+7
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit7
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit7:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit7
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit7:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit7
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit7:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit7
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit7:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit7
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit7:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit7
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit7:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit7
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit7:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit7
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit7:
    
   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
    cbi PORTD,4
    	// ---------------------
	//
	//    	Eigth row  	 
	//
	// ---------------------
    	//	Activate the row bit for this row (C0)
    	sbi	PORTD,5
    	//	Read first byte from memory, store in r16
    	LDD	r16, Y+8
    	//	Load comparator-byte
    	ldi	r17, 0b00000001
    	//	Load byte to do AND operation with
    	ldi	r18, 0b00000001
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000001 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFirstBit8
    	//	Sets first bit on row 1
    	SBI	PORTD,6
	skipFirstBit8:
    	// Move bit in comparator-byte one step (0b00000010)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000010)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSecondBit8
    	//	Sets bit on row 1
    	SBI	PORTD,7
	skipSecondBit8:
    	// Move bit in comparator-byte one step (0b00000100)
    	lsl r17
    	// Copy it to r18 to reset it (0b00000100)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipThirdBit8
    	//	Sets bit on row 1
    	SBI	PORTB,0
	skipThirdBit8:
    	// Move bit in comparator-byte one step (0b00001000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00001000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFourthBit8
    	//	Sets bit on row 1
    	SBI	PORTB,1
	skipFourthBit8:
    	// Move bit in comparator-byte one step (0b00010000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00010000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipFifthBit8
    	//	Sets bit on row 1
    	SBI	PORTB,2
	skipFifthBit8:
    	// Move bit in comparator-byte one step (0b00100000)
    	lsl r17
    	// Copy it to r18 to reset it (0b00100000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSixthBit8
    	//	Sets bit on row 1
    	SBI	PORTB,3
	skipSixthBit8:
    	// Move bit in comparator-byte one step (0b01000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b01000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipSeventhBit8
    	//	Sets bit on row 1
    	SBI	PORTB,4
	skipSeventhBit8:
    	// Move bit in comparator-byte one step (0b10000000)
    	lsl r17
    	// Copy it to r18 to reset it (0b10000000)
    	mov	r18,r17
    	//	Do AND operation with r16 and r18, the result will be either 00000000 (don't set the bit) or 00000010 (set the bit)
    	and r18,r16
    	//	If r18 is equal to r17 (comparator-byte) set the bit, else move on
    	cp	r18,r17
    	brne skipEigthBit8
    	//	Sets bit on row 1
    	SBI	PORTB,5
	skipEigthBit8:
    
   	 cbi PORTD,6
   	 cbi PORTD,7
   	 cbi PORTB,0
   	 cbi PORTB,1
   	 cbi PORTB,2
   	 cbi PORTB,3
   	 cbi PORTB,4
   	 cbi PORTB,5
    
    	//	Clear all "my" bits on this row, (D6,D7,B0,B1,B2,B3,B4,B5)
  	 
    	//	Deactivate this row bit, goto next row
    	CBI	PORTD,5
	//-----------------------------
	//	Check if updateflag is set 
	//-----------------------------
	cpi rUpdateFlag, 1
	breq	updateLoop

	jmp	gameloop
updateLoop:
	// Do stuff here, like get joystick input, "move" snake in memory (set a 1 in the direction the snake is currently
	// traveling in, and set a zero where the snake tail "ends", making the snake "move" one step on the display.
	
	// Delays the gameupdate, only updating every 15 interrupts
	INC rUpdateDelay				// Increase rUpdateDelay by 1 (one)
	cpi rUpdateDelay, 15			// rUpdateDelay - 15
	breq continueUpdate				// If SREG zero flag = 0, goto continueUpdate
	ldi rUpdateFlag, 0b00000000		// Else, reset updateflag
	jmp gameLoop					// goto gameLoop
	
	//----------------------
	//	Y-Axis source port
	//----------------------	
continueUpdate:
	ldi rUpdateDelay, 0				// Reset rUpdateDelay
	// Source port ( Y-axis )		// Choose source port
	ldi r16, 0b00000100				// Port 4 ( y-axis )
	lds r18, ADMUX					// Load ADMUX into r18
	or r18,r16						// OR r16,r18 --> result in r18
	sts ADMUX, r18					// Write r18 back to ADMUX



	// Start convert ( Y-axis ). Set bit ADSC in ADCSRA to 1
	ldi r16, 1<<ADSC	// Set bit ADSC to 1, store in r16
	lds r18, ADCSRA		// Store ADCSRA in r18
	or r18,r16			// OR them together, store in r18
	sts ADCSRA, r18		// Write r18 back to ADCSRA
	// Iterate ( Y-axis )
iterateY:
	lds r18,ADCSRA		// Store ADCSRA in r18
	sbrc r18, 6			// If 6th bit is 0 (zero), skip the next instruction
	jmp iterateY		// If 6th bit in previous is 1 (one), goto iterateY
	lds r18,ADCH		// Load result from joystick input into r18 (value between 0-255 )



	//ldi r19, 140		// Load 140 into r19
	//cp	r19,r18			// Compare r18,r19 ( r19-r18 ) Sets SREG
	//brge skipY			// if(r18 >= 140) goto skip


	// Print value of joystick y-axis to top row
	//std	Y+1, r18
	// Set y-movement flag
	cpi r18,255
	brne notYmax
	ldi	rDirectionFlag, 0b00000001	// Sets "up" flag
notYmax:
	cpi	r18,0
	brne notYmin
	ldi	rDirectionFlag, 0b00000010	// Sets "down" flag
notYmin:
	// Direction flag to screen
	//std	Y+8, rDirectionFlag
//skipY:
	// Restore ADCSRA and ADMUX
	 ldi r16, 0b01100000
   	 sts ADMUX,r16
   	 ldi r16,0b10000111
   	 sts ADCSRA,r16

	//----------------------
	//	X-Axis source port
	//----------------------

	// Source port ( X-axis )
	ldi r16, 0b00000101
	lds r18, ADMUX
	or r18,r16
	sts ADMUX, r18
	// Start convert ( X-axis )
	ldi r16, 1<<ADSC
	lds r18, ADCSRA
	or r18,r16
	sts ADCSRA, r18
	// Iterate ( X-axis )
iterateX:
	lds r18,ADCSRA
	sbrc r18, 6
	jmp iterateX
	lds r18,ADCH
	
	//ldi r19, 140
	//cp	r19,r18 //	if(r18 >= 140) goto skip
	//brge skipX
	
	// Print value of joystick x-axis to second row
	//std	Y+2, r18
	// Set x-movement flag
	cpi r18,255
	brne notXmax
	ldi	rDirectionFlag, 0b00000100	// Sets "left" flag
notXmax:
	cpi	r18,0
	brne notXmin
	ldi	rDirectionFlag, 0b00001000	// Sets "right" flag
notXmin:
	//std	Y+8, rDirectionFlag
//skipX:

	// Restore ADCSRA and ADMUX
	ldi r16, 0b01100000
   	sts ADMUX,r16
   	ldi r16,0b10000111
   	 sts ADCSRA,r16

	// TEST MOVING A BIT X+ AND X-
	/*
	cpi rDirectionFlag, 8
	brne notRight
	cpi r23,0
	brne DontSetCarry1
	SEC
DontSetCarry1:
	ROL r23
notRight:
	cpi	rDirectionFlag, 4
	brne notLeft
	cpi r23,0
	brne DontSetCarry2
	SEC
DontSetCarry2:
	ROR r23
notLeft:
	std	Y+4, r23
	*/
   	//-------------------
	//	Clear update flag, so we only update the display, until we get another CPU-interrupt
	//	where we again set the flag so the updateLoop runs once move, and repeat.
	//-------------------
	ldi rUpdateFlag, 0b00000000
	
	
	CLZ
	cpi	rDirectionFlag,1
	brne skipUpMovement
	call upMovement
	skipUpMovement:
	

	CLZ
	cpi	rDirectionFlag,2
	brne skipDownMovement
	call downMovement
	skipDownMovement:
	
	CLZ
	cpi rDirectionFlag,4
	brne skipLeftMovement
	call leftMovement
	skipLeftMovement:
	
	CLZ
	cpi rDirectionFlag,8
	brne skipRightMovement
	call rightMovement
	skipRightMovement:
	
	 // Loop
   	 jmp gameloop
    	
tick:
	ldi	rUpdateFlag, 0b00000001
	reti
	

//-------------------------
//	Move up subroutine
//-------------------------

upMovement:
	
	cpi rRowOffset, 1
	brne notRowOneUp
	LDD rCurrentByte, Y+1
	std Y+8,rCurrentByte
	ldi rRowOffset,0b00001000
	std Y+1, r23
	ret
notRowOneUp:

	cpi rRowOffset, 2
	brne notRowTwoUp
	LDD rCurrentByte, Y+2
	std Y+1,rCurrentByte
	DEC rRowOffset
	std Y+2, r23
	ret
notRowTwoUp:

	cpi rRowOffset, 3
	brne notRowThreeUp
	LDD rCurrentByte, Y+3
	std Y+2,rCurrentByte
	DEC rRowOffset
	std Y+3, r23
	cp	r23,r23
	ret
notRowThreeUp:

	cpi rRowOffset, 4
	brne notRowFourUp
	LDD rCurrentByte, Y+4
	std Y+3,rCurrentByte
	DEC rRowOffset
	std Y+4, r23
	ret
notRowFourUp:

	cpi rRowOffset, 5
	brne notRowFiveUp
	LDD rCurrentByte, Y+5
	std Y+4,rCurrentByte
	DEC rRowOffset
	std Y+5, r23
	ret
notRowFiveUp:

	cpi rRowOffset, 6
	brne notRowSixUp
	LDD rCurrentByte, Y+6
	std Y+5,rCurrentByte
	DEC rRowOffset
	std Y+6, r23
	ret
notRowSixUp:

	cpi rRowOffset, 7
	brne notRowSevenUp
	LDD rCurrentByte, Y+7
	std Y+6,rCurrentByte
	DEC rRowOffset
	std Y+7, r23
	ret

notRowSevenUp:

	cpi rRowOffset, 8
	brne notRowEightUp
	LDD rCurrentByte, Y+8
	std Y+7,rCurrentByte
	DEC rRowOffset
	std Y+8, r23
notRowEightUp:
	ret
	
//-------------------------
//	Move down subroutine
//-------------------------

downMovement:
	
	cpi rRowOffset, 8
	brne notRowEightDown
	LDD rCurrentByte, Y+8
	std Y+1,rCurrentByte
	ldi rRowOffset, 0b00000001
	std Y+8, r23
	ret
notRowEightDown:

	cpi rRowOffset, 7
	brne notRowSevenDown
	LDD rCurrentByte, Y+7
	std Y+8,rCurrentByte
	INC rRowOffset
	std Y+7, r23
	ret
notRowSevenDown:

	cpi rRowOffset, 6
	brne notRowSixDown
	LDD rCurrentByte, Y+6
	std Y+7,rCurrentByte
	INC rRowOffset
	std Y+6, r23
	ret
notRowSixDown:

	cpi rRowOffset, 5
	brne notRowFiveDown
	LDD rCurrentByte, Y+5
	std Y+6,rCurrentByte
	INC rRowOffset
	std Y+5, r23
	ret
notRowFiveDown:

	cpi rRowOffset, 4
	brne notRowFourDown
	LDD rCurrentByte, Y+4
	std Y+5,rCurrentByte
	INC rRowOffset
	std Y+4, r23
	ret
notRowFourDown:
	
	cpi rRowOffset, 3
	brne notRowThreeDown
	LDD rCurrentByte, Y+3
	std Y+4,rCurrentByte
	INC rRowOffset
	std Y+3, r23
	ret
notRowThreeDown:

	cpi rRowOffset, 2
	brne notRowTwoDown
	LDD rCurrentByte, Y+2
	std Y+3,rCurrentByte
	INC rRowOffset
	std Y+2, r23
	ret
notRowTwoDown:

	cpi rRowOffset, 1
	brne notRowOneDown
	LDD rCurrentByte, Y+1
	std Y+2,rCurrentByte
	INC rRowOffset
	std Y+1, r23
	ret
notRowOneDown:
	ret

//-------------------------
//	Move left subroutine
//-------------------------

leftMovement:
	cpi rRowOffset, 1
	brne notRowOneLeft
	LDD rCurrentByte, Y+1
	cpi rCurrentByte,0
	brne DontSetCarry1
	SEC
DontSetCarry1:
	ROR rCurrentByte
	std Y+1, rCurrentByte
	ret
notRowOneLeft:
	
	cpi rRowOffset, 2
	brne notRowTwoLeft
	LDD rCurrentByte, Y+2
	cpi rCurrentByte,0
	brne DontSetCarry2
	SEC
DontSetCarry2:
	ROR rCurrentByte
	std Y+2, rCurrentByte
	ret
notRowTwoLeft:
	
	cpi rRowOffset, 3
	brne notRowThreeLeft
	LDD rCurrentByte, Y+3
	cpi rCurrentByte,0
	brne DontSetCarry3
	SEC
DontSetCarry3:
	ROR rCurrentByte
	std Y+3, rCurrentByte
	ret
notRowThreeLeft:

	cpi rRowOffset, 4
	brne notRowFourLeft
	LDD rCurrentByte, Y+4
	cpi rCurrentByte,0
	brne DontSetCarry4
	SEC
DontSetCarry4:
	ROR rCurrentByte
	std Y+4, rCurrentByte
	ret
notRowFourLeft:

	cpi rRowOffset, 5
	brne notRowFiveLeft
	LDD rCurrentByte, Y+5
	cpi rCurrentByte,0
	brne DontSetCarry5
	SEC
DontSetCarry5:
	ROR rCurrentByte
	std Y+5, rCurrentByte
	ret
notRowFiveLeft:

	cpi rRowOffset, 6
	brne notRowSixLeft
	LDD rCurrentByte, Y+6
	cpi rCurrentByte,0
	brne DontSetCarry6
	SEC
DontSetCarry6:
	ROR rCurrentByte
	std Y+6, rCurrentByte
	ret
notRowSixLeft:

	cpi rRowOffset, 7
	brne notRowSevenLeft
	LDD rCurrentByte, Y+7
	cpi rCurrentByte,0
	brne DontSetCarry7
	SEC
DontSetCarry7:
	ROR rCurrentByte
	std Y+7, rCurrentByte
	ret
notRowSevenLeft:

	cpi rRowOffset, 8
	brne notRowEightLeft
	LDD rCurrentByte, Y+8
	cpi rCurrentByte,0
	brne DontSetCarry8
	SEC
DontSetCarry8:
	ROR rCurrentByte
	std Y+8, rCurrentByte
	ret
notRowEightLeft:

ret

//-------------------------
//	Move right subroutine
//-------------------------
rightMovement:
	cpi rRowOffset, 1
	brne notRowOneRight
	LDD rCurrentByte, Y+1
	cpi rCurrentByte,0
	brne DontSetCarry1Right
	SEC
DontSetCarry1Right:
	ROL rCurrentByte
	std Y+1, rCurrentByte
	ret
notRowOneRight:
	
	cpi rRowOffset, 2
	brne notRowTwoRight
	LDD rCurrentByte, Y+2
	cpi rCurrentByte,0
	brne DontSetCarry2Right
	SEC
DontSetCarry2Right:
	ROL rCurrentByte
	std Y+2, rCurrentByte
	ret
notRowTwoRight:
	
	cpi rRowOffset, 3
	brne notRowThreeRight
	LDD rCurrentByte, Y+3
	cpi rCurrentByte,0
	brne DontSetCarry3Right
	SEC
DontSetCarry3Right:
	ROL rCurrentByte
	std Y+3, rCurrentByte
	ret
notRowThreeRight:

	cpi rRowOffset, 4
	brne notRowFourRight
	LDD rCurrentByte, Y+4
	cpi rCurrentByte,0
	brne DontSetCarry4Right
	SEC
DontSetCarry4Right:
	ROL rCurrentByte
	std Y+4, rCurrentByte
	ret
notRowFourRight:

	cpi rRowOffset, 5
	brne notRowFiveRight
	LDD rCurrentByte, Y+5
	cpi rCurrentByte,0
	brne DontSetCarry5Right
	SEC
DontSetCarry5Right:
	ROL rCurrentByte
	std Y+5, rCurrentByte
	ret
notRowFiveRight:

	cpi rRowOffset, 6
	brne notRowSixRight
	LDD rCurrentByte, Y+6
	cpi rCurrentByte,0
	brne DontSetCarry6Right
	SEC
DontSetCarry6Right:
	ROL rCurrentByte
	std Y+6, rCurrentByte
	ret
notRowSixRight:

	cpi rRowOffset, 7
	brne notRowSevenRight
	LDD rCurrentByte, Y+7
	cpi rCurrentByte,0
	brne DontSetCarry7Right
	SEC
DontSetCarry7Right:
	ROL rCurrentByte
	std Y+7, rCurrentByte
	ret
notRowSevenRight:

	cpi rRowOffset, 8
	brne notRowEightRight
	LDD rCurrentByte, Y+8
	cpi rCurrentByte,0
	brne DontSetCarry8Right
	SEC
DontSetCarry8Right:
	ROL rCurrentByte
	std Y+8, rCurrentByte
	ret
notRowEightRight:

ret