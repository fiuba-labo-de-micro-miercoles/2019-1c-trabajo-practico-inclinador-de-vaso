.cseg
.org 0x00
	jmp  main

.org 0x01A
	jmp INT_TIMER1_OVF

.org INT_VECTORS_SIZE

main:
	ldi	 r16, HIGH(RAMEND)
	out  sph, r16
	ldi  r16, LOW(RAMEND)
	out  spl, r16		; inicializo el stack pointer al final de la RAM
	sei
	rcall servo_init
	rcall dellay
	rcall dellay
	clr   r18

here:	
	rcall servo_pull
	rcall dellay
	inc   r18
	cpi  r18, 40
	brsh main
	rjmp here



; ============================================================================
servo_init:
	push r16
	
	sbi  DDRB, PB1			; PB1 como output pin

	ldi  r16, HIGH(313 + 8)
	sts  OCR1AH, r16

	ldi  r16, LOW(313 + 8)
	sts  OCR1AL, r16

	ldi  r16, (1<<WGM11)|(1<<WGM10)|(1<<COM1A1)|(0<<COM1A0)			; fast-PWM mode, non-inverting mode
	sts  TCCR1A, r16					

	ldi  r16, (0<<WGM13)|(1<<WGM12)|(1<<CS02)|(0<<CS01)|(1<<CS00)
	sts  TCCR1B, r16												; con prescaler = 1024

	ldi  r16, (1<<TOIE1)
	sts  TIMSK1, r16												; se activa interrupciones

	pop  r16
	ret

; ============================================================================
servo_pull:
	push r16
	push r17

	cpi  r18,33
	brsh servo_pull_end												; si es mayor a 32 el valor que recibe significa que esta fuera del rango de 250-500gr.
	
	ldi  r16, LOW(313 + 8)
	ldi  r17, HIGH(313 + 8)

	add  r16, r18
	brcc servo_pull_next
	inc  r17
servo_pull_next:
	sts OCR1AL, r16
	sts OCR1AH, r17 

servo_pull_end:	
	pop  r17
	pop  r16
	ret
; ============================================================================
INT_TIMER1_OVF:
	push r16

	ldi  r16, HIGH(313)
	sts  TCNT1H, r16
	ldi  r16, LOW(313)
	sts  TCNT1L, r16

	pop  r16
	reti
; ============================================================================
dellay:
	push r20
	push r21
	push r22

	ldi  r20, 32
dellay_L1: ldi  r21,200
dellay_L2: ldi  r22, 250	
dellay_L3:	
	nop
	nop
	dec  r22
	brne dellay_L3

	dec  r21
	brne dellay_L2

	dec  r20
	brne dellay_L1
	
	pop  r22
	pop  r21
	pop  r20
	
	ret