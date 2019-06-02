;-------------------------------------------------------------------------
; S.H.I.V.A.
; Sistema Hibrido Inclinador de Vaso Automatizado
;-------------------------------------------------------------------------
;-------------------------------------------------------------------------
; MCU: ATmega328p con oscilador interno a 16 MHz
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
; INCLUSIONES
;-------------------------------------------------------------------------
.include "m328pdef.inc"

;-------------------------------------------------------------------------
; CONSTANTES y MACROS
;-------------------------------------------------------------------------
.equ  SCK  = PC0					; pin donde se conecta SCK
.equ  DOUT = PC1					; pin donde se conecta DOUT
.equ  BAUD_RATE = 207				; baudrate=9600 e=0.2% U2X0=1
;-------------------------------------------------------------------------
; variables en SRAM
;-------------------------------------------------------------------------
		.dseg 

;-------------------------------------------------------------------------
; variables en registros
;-------------------------------------------------------------------------
.def  CONT_8 = r17
.def  DATO_H = r4
.def  DATO_M = r3
.def  DATO_L = r2

;-------------------------------------------------------------------------
; codigo
;-------------------------------------------------------------------------

		.cseg 
.org 0x00
	jmp  main

.org INT_VECTORS_SIZE

main:
	ldi	 r16, HIGH(RAMEND)
	out  sph, r16
	ldi  r16, LOW(RAMEND)
	out  spl, r16					; inicializo el stack pointer al final de la RAM

    rcall configuracion_puertos

	rcall USART_init
	
	;rcall lectura_peso

	clr   r4
	inc   r4
loop:	rcall USART_transmit
		inc r4
		rjmp loop

here: jmp here


;-------------------------------------------------------------------------
; FUNCIONES
;-------------------------------------------------------------------------

configuracion_puertos:
	sbi  DDRC, SCK					; puerto PC0 = A0 como salida (SCK)

	cbi  DDRC, DOUT
	sbi  PORTC, DOUT				; puerto PC = A1 como entrada (DOUT)
	ret

;-------------------------------------------------------------------------
; lectura_peso: 
; funcion para la lectura de datos de la celda de carga. Carga
; los bits enviados por el amplificador HX711 a traves del pin DOUT y los
; guarda en los registros r4:r2. Usa los registros r16 y r17
;-------------------------------------------------------------------------

lectura_peso:
	push  r16
	push  r17

	sbic  PINC, DOUT					
	rjmp  lectura_peso				; chequeo si DOUT está en alto
	nop							
	nop 							; Espero dos ciclos y vuelvo a preguntar si sigue en alto ya que
	sbic  PINC, DOUT				; por la hoja de datos, DOUT debe estar como minimo 0.1 useg en 0
	rjmp  lectura_peso				; para indicar que tiene un dato disponible para mandar.

	rcall cargar_byte				; lee 8 bits y los guarda en r16
	mov   DATO_H, r16				; primer byte es el mas significativo
	rcall cargar_byte
	mov   DATO_M, r16
	rcall cargar_byte
	mov   DATO_L, r16

	sbi   PORTC, SCK				; se genera el pulso numero 25 requerido para setear el DOUT
	nop								; debe estar un tiempo en alto mayor a 0.2 useg
	nop
	nop
	nop
	cbi   PORTC, SCK
	pop   r17
	pop   r16
	ret


cargar_byte:
	clr   r16
	ldi   CONT_8, 8
cargar_bit:
	sbi   PORTC, SCK				; se genera un flanco ascendente en la señal SCK para cargar un bit
	sbic  PORTC, DOUT				; si en DOUT hay un 1, se incrementa r16 y pone un 1 en el LSB	
	inc   r16						; si en DOUT hay un 0, salte esta instruccion y deja un 0 en LSB	
	cbi   PORTC, SCK				; se genera un flanco descendente en la señal SCK para cargar un bit
	lsl   r16
	dec   CONT_8
	brne  cargar_bit
	ret



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

	ldi  r16, (1<<RXCIE0)|(1<<TXCIE0)|(0<<RXEN0)|(1<<TXEN0)|(0<<UCSZ02)			  ; Habilito interrupciones de recepcion y transmision
	sts  UCSR0B, r16															  ; habilito transmision y deshabilito recepcion, configuro la cantidad
	pop  r16
	ret																			  ; de bits del dato	

USART_transmit:
	push r16
	lds   r16, UCSR0A				; cargo el resgistro de control en un registro
	sbrs r16, UDRE0					; verifico si el buffer de datos esta vacio
	rjmp USART_transmit   
	sts  UDR0, r4					; el buffer estaba vacio entonces se puede cargar con los datos
	pop  r16
	ret