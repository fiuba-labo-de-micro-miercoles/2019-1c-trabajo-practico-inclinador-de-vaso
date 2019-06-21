;-------------------------------------------------------------------------
; CONFIGURACION_PUERTOS:
;-------------------------------------------------------------------------
configuracion_puertos:
	push r16
									; CELDA DE CARGA	
	sbi  DDRC, SCK					; puerto PC0 = A0 como salida (SCK)

	sbi  DDRC, PC2					; leds de prueba
	sbi  DDRC, PC3
									; PRUEBAS
	cbi  DDRC, DOUT
	sbi  PORTC, DOUT				; puerto PC = A1 como entrada (DOUT) 
																		
	ldi  r16, 0xF0					; PANTALLA LCD		
	out  LCD_DDDR, r16				; Configuro los bits D7:D4 del puerto D como de salida
	sbi  LCD_CDDR, LCD_RS		
	sbi  LCD_CDDR, LCD_RW
	sbi  LCD_CDDR, LCD_E			; Configuro los puertos de dato (PORTD) y los comandos usados (del PORTB) como de salida 
	rcall delay_3ms
	pop  r16
	ret

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
; LCD_INIT:
;-------------------------------------------------------------------------
LCD_init:
	push  r16

	ldi   r16, DATA_4BIT			; Trabajamos enviando los caracteres de a 4 bits
	rcall send_command
	rcall delay_3ms
	
	ldi   r16, DISP_ON_CURS_OFF		; Deja el cursor fijo
	rcall send_command				
	rcall delay_3ms

	pop   r16
	ret