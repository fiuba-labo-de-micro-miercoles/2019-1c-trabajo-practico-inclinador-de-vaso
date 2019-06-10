; ----------------------------------------------------------------------
; INICIALIZACION DE LA UART EN MODO TRANSMISION
; ----------------------------------------------------------------------
USART_init:
	push r16
		
	ldi  r16, high(BAUD_RATE)		; configuracion del baudrate = 9600  		
	sts  UBRR0H, r16
	ldi  r16, low(BAUD_RATE)	
	sts  UBRR0L, r16
	
	ldi  r16, (1<<U2X0)				; doble velocidad
	sts	 UCSR0A, r16

	ldi  r16, (0<<UMSEL01)|(0<<UMSEL00)|(0<<UPM01)|(0<<UPM00)|(0<<USBS0)|(1<<UCSZ01)|(1<<UCSZ00) ; Trama: modo asincronico,sin paridad8 bits de datos y 1 bit de stop 
	sts  UCSR0C, r16																			 

	ldi  r16, (1<<RXCIE0)|(1<<TXCIE0)|(1<<UDRIE0)|(0<<RXEN0)|(1<<TXEN0)|(0<<UCSZ02)	; Habilito interrupciones de recepcion y transmision
	sts  UCSR0B, r16																; habilito transmision y deshabilito recepcion, configuro la cantidad
																					; de bits del dato	
	pop  r16
	ret																				

;-------------------------------------------------------------------------
; CONFIGURACION_PUERTOS:
;-------------------------------------------------------------------------
configuracion_puertos:
	sbi  DDRC, SCK					; puerto PC0 = A0 como salida (SCK)

	sbi  DDRC, PC2					; leds de prueba
	sbi  DDRC, PC3

	cbi  DDRC, DOUT
	sbi  PORTC, DOUT				; puerto PC = A1 como entrada (DOUT)
	ret

