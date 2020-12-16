//.include "utils.inc"
.equ	E = 1
.equ	RS = 0
.equ	FN_SET = $28
.equ	DISP_ON = $0F
.equ	LCD_CLR = $01
.equ	E_MODE = $06
.equ	RET_HOME = $03
.equ	ERASE = $01

.dseg
	//.org	$0100
	TEXT:	.byte 16
.cseg


jmp		START

INIT_PORTS:
	sbi		DDRB, 0
	sbi		DDRB, 1
	sbi		DDRB, 2
	ldi		r16, $F0
	out		DDRD, r16
	ret

START:
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	ldi		r16, LOW(RAMEND)
	out		SPL, r16

	call	INIT_PORTS
	
	call	LCD_INIT
	call	LCD_CLEAR
	ldi		r16, 10
	call	DELAY
	
	call	MAIN
	call	LCD_HOME


LCD_INIT:
	call	BACKLIGHT_OFF
	call	DELAY
	call	BACKLIGHT_ON
	call	DELAY

	ldi		r16 , $30
	call	LCD_WRITE4
	call	LCD_WRITE4
	call	LCD_WRITE4
	ldi		r16 , $20
	call	LCD_WRITE4

	; -- 
	ldi		r16 , FN_SET
	call	LCD_COMMAND

	; --- Display on , cursor on , cursor blink
	ldi		r16 , DISP_ON
	call	LCD_COMMAND

	; --- Clear display
	ldi		r16 , LCD_CLR
	call	LCD_COMMAND

	; --- Entry mode : Increment cursor , no shift
	ldi		r16 , E_MODE
	call	LCD_COMMAND

	ret

MAIN:
	call	TEXT_TEST
	ldi		ZH, HIGH(TEXT)
	ldi		ZL, LOW(TEXT)
	call	LCD_PRINT


LOOP:
	call	KEY_READ

	cpi		r16, 2
	breq	CALL_LEFT

	cpi		r16, 5
	breq	CALL_RIGHT
	
	jmp		LOOP



CALL_LEFT:
	call	LEFT
	jmp		LOOP

CALL_RIGHT:
	call	RIGHT
	jmp		LOOP

BACKLIGHT_ON:
	sbi		PORTB, 2
	ret

BACKLIGHT_OFF:
	cbi		PORTB, 2
	ret

LCD_WRITE4:
	sbi		PORTB, E
	out		PORTD, r16
	call	WAIT
	cbi		PORTB, E 	
	ret

LCD_WRITE8:
	call	LCD_WRITE4
	swap	r16
	call	LCD_WRITE4
	ret

LCD_COMMAND:
	cbi		PORTB, RS
	call	LCD_WRITE8
	ret

LCD_ASCII:
	sbi		PORTB, RS
	call	LCD_WRITE8
	ret

LCD_CLEAR:
	ldi		r16, ERASE
	call	LCD_COMMAND
	ret

LCD_HOME:
	ldi		r16, RET_HOME
	call	LCD_COMMAND
	ret

LCD_COL:
	ldi		r17, $80
	add		r16, r17
	dec		r16
	call	LCD_COMMAND
	ret
	
LEFT:
	cpi		r19, 0
	breq	LEFT_EXIT
	dec		r19
	mov		r16, r19
	call	LCD_COL
LEFT_EXIT:
	ret

RIGHT:
	cpi		r19, $10
	breq	RIGHT_EXIT
	inc		r19			//Kan man spara i r19 eller SRAM? FRÅGA MICKE
	mov		r16, r19
	call	LCD_COL
RIGHT_EXIT:
	ret


DONE:
	call	DONE
	

LCD_PRINT_HEX:
	mov		r17, r16
	swap	r16
	andi	r16, $0F

	call	PRINT_NIBBLE

	mov		r16, r17
	andi	r16, $0F

	call	PRINT_NIBBLE
	ret	

PRINT_DONE:
	ret


HIGHER_NIBBLE:	
			
	
	cpi		r16, $0A

	brmi	BELOW_TEN

	ldi		r18, $37
	add		r16, r18
	jmp		CONVERT_EXIT


LOWER_NIBBLE:	
	mov		r17, r16
	swap	r17
	andi	r17, $F0
	cpi		r17, $0A

	brmi	BELOW_TEN

	ldi		r18, $37
	add		r17, r18
	jmp		CONVERT_EXIT

BELOW_TEN:
	ldi		r18, $30
	add		r17, r18

CONVERT_EXIT:
	ret

PRINT_NIBBLE:
	cpi		r16, $0A

	brmi	BELOW_TEN2

	ldi		r18, $37
	add		r16, r18
	jmp		PRINT_NIBBLE_EXIT

	BELOW_TEN2:
	ldi		r18, $30
	add		r16, r18

PRINT_NIBBLE_EXIT:
	call	LCD_ASCII
	ret

	
ADC_READ8:
	ldi		r16, $60		// left adjust result
	sts		ADMUX, r16
	ldi		r16, $87		//PRESCELAR
	sts		ADCSRA, r16
	
CONVERT:
	lds		r16, ADCSRA
	ori		r16, (1 << ADSC)	;Sätt ADSC biten. Hoppar sex steg till vänster och sätter den biten till 1
	sts		ADCSRA, r16			; Startar en omvandling
	call	WAIT

WAIT_ADC:
	lds		r16, ADCSRA
	sbrc	r16, ADSC		; om nollställd är vi klara
	rjmp	WAIT_ADC		; annars testa busy-biten igen
	lds		r16, ADCH		; En läsning av hög byte
	ret

	KEY:
	call	ADC_READ8
//	ldi		r16, 4

	cpi		r16, 207
	brsh	NO_KEY
	
	cpi		r16, 129
	brsh	KEY_ONE
	
	cpi		r16, 83
	brsh	KEY_TWO
	
	cpi		r16, 44
	brsh	KEY_THREE
	
	cpi		r16, 12
	brsh	KEY_FOUR
	
	jmp		KEY_FIVE

NO_KEY:
	ldi		r16, 0
	jmp		KEY_EXIT

KEY_ONE:
	ldi		r16, 1
	jmp		KEY_EXIT

KEY_TWO:
	ldi		r16, 2
	jmp		KEY_EXIT

KEY_THREE:
	ldi		r16, 3
	jmp		KEY_EXIT

KEY_FOUR:
	ldi		r16, 4
	jmp		KEY_EXIT

KEY_FIVE:
	ldi		r16, 5
	

KEY_EXIT:
	ret




KEY_READ :
	call KEY
	tst r16
	brne KEY_READ ; old key still pressed

KEY_WAIT_FOR_PRESS :
	call KEY
	tst r16
	breq KEY_WAIT_FOR_PRESS ; no key pressed
		; new key value available
	ret


TEXT_TEST:
	ldi		ZH, HIGH(TEXT)
	ldi		ZL, LOW(TEXT)

	ldi		r16, $41
	ldi		r17, 0
	call	TEXT_LOOP
	ret

TEXT_LOOP:
	inc		r16
	inc		r17
	cpi		r17, 5
	breq	TEXT_LOOP_EXIT
	st		Z+, r16
	jmp		TEXT_LOOP
TEXT_LOOP_EXIT:
	ldi		r16, 0
	st		Z, r16
	ret

LCD_PRINT:
	ld		r16, Z+
	cpi		r16, 0
	breq	LCD_PRINT_DONE	
	call	LCD_ASCII
	jmp		LCD_PRINT

	LCD_PRINT_DONE:
	ret

WAIT:
	adiw	r24,1
	brne	WAIT
	ret
	
	DELAY:
	ldi		r16, 1
	DELAY_LOOP:
	call	WAIT
	dec		r16
	brne	DELAY_LOOP
	ret
