;-------------------------------------------------------------------------
; CONFIGURACION_PUERTOS:
; se definen los puertos de entrada o de salda para todo el programa
;-------------------------------------------------------------------------
configuracion_puertos:
	push r16
									; CELDA DE CARGA	
	sbi  DDRC, SCK					; puerto PC0 = A0 como salida (SCK)
	cbi  DDRC, DOUT
	sbi  PORTC, DOUT				; puerto PC = A1 como entrada (DOUT) 

									; SERVO
	sbi  DDRB, PB1					; PB1 como output pin						
	
	ldi  r16, 0xF0					; PANTALLA LCD		
	out  LCD_DDDR, r16				; Configuro los bits D7:D4 del puerto D como de salida
	sbi  LCD_CDDR, LCD_RS		
	sbi  LCD_CDDR, LCD_RW
	sbi  LCD_CDDR, LCD_E			; Se configura los puertos de dato (PORTD) y los comandos usados (del PORTB) como de salida 
	rcall delay_3ms

	pop  r16
	ret											

;-------------------------------------------------------------------------
; LCD_INIT:
; se define el formato en que se le envian los datos a la pantalla, y el 
; formato del cursor.
;-------------------------------------------------------------------------
LCD_init:
	push  r16

	ldi   r16, DATA_4BIT			; Trabajamos enviando los caracteres de a 4 bits
	rcall send_command
	rcall delay_3ms
	
	ldi   r16, DISP_ON_CURS_OFF		; Sin cursor
	rcall send_command				
	rcall delay_3ms

	pop   r16
	ret

;-------------------------------------------------------------------------
; SERVO_INIT:
; Inicializa la posición del servo tal que la plataforma se encuentre en
; posición vertical. Envia un PWM de periodo 20 ms y tiempo en alto 0,5 ms
; por el pin correspondiente al TIMER1A
;-------------------------------------------------------------------------
servo_init:
	push r16

	ldi  r16, HIGH(313 + 7)
	sts  OCR1AH, r16

	ldi  r16, LOW(313 + 7)
	sts  OCR1AL, r16

	ldi  r16, (1<<WGM11)|(1<<WGM10)|(1<<COM1A1)|(0<<COM1A0)			; fast-PWM mode, non-inverting mode
	sts  TCCR1A, r16					

	ldi  r16, (0<<WGM13)|(1<<WGM12)|(1<<CS02)|(0<<CS01)|(1<<CS00)
	sts  TCCR1B, r16												; con prescaler = 1024

	ldi  r16, (1<<TOIE1)
	sts  TIMSK1, r16												; se activa interrupciones

	pop  r16
	ret
