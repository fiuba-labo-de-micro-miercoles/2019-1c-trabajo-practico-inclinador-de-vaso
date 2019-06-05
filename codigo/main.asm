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

.org	0x0026		; USART Data Register Empty
		rjmp	ISR_REG_USART_VACIO

.org INT_VECTORS_SIZE

main:
	ldi	 r16, HIGH(RAMEND)
	out  sph, r16
	ldi  r16, LOW(RAMEND)
	out  spl, r16					; inicializo el stack pointer al final de la RAM


    rcall configuracion_puertos
	rcall USART_init					
		
here:
	rcall lectura_peso
	rcall dellay
	rcall dellay
	rcall send_data
	

	rjmp here

;-------------------------------------------------------------------------
; FUNCIONES
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
; CONFIGURACION_PUERTOS:
;-------------------------------------------------------------------------
configuracion_puertos:
	sbi  DDRC, SCK					; puerto PC0 = A0 como salida (SCK)

	cbi  DDRC, DOUT
	sbi  PORTC, DOUT				; puerto PC = A1 como entrada (DOUT)
	ret

;-------------------------------------------------------------------------
; LECTURA_PESO: 
; funcion para la lectura de datos de la celda de carga. Carga
; los bits enviados por el amplificador HX711 a traves del pin DOUT y los
; guarda en los registros r4:r2. Usa los registros r16 y r17
;-------------------------------------------------------------------------

lectura_peso:
	push  r16
	push  r17

loop:
	sbic  PINC, DOUT					
	rjmp  loop						; chequeo si DOUT está en alto
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
	nop
	lsl   r16
	sbic  PINC, DOUT				; si en DOUT hay un 1, se incrementa r16 y pone un 1 en el LSB	
	inc   r16						; si en DOUT hay un 0, salte esta instruccion y deja un 0 en LSB	
	cbi   PORTC, SCK				; se genera un flanco descendente en la señal SCK para cargar un bit
	dec   CONT_8
	brne  cargar_bit
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

; ----------------------------------------------------------------------------
; SEND_DATA: 
; envia los registros r4:r2 por la USART
; ----------------------------------------------------------------------------

send_data:
	push r16
	ldi  zh, HIGH(0x04)
	ldi  zl, LOW(0x04)						
	sei
	lds  r16, UCSR0B
	sbr  r16, 1<<UDRIE0
	sts  UCSR0B, r16				; habilito interrupciones 
	pop  r16
	ret

; ----------------------------------------------------------------------
; INTERRUPCION PARA EL CODIGO DE PRUEBAS
; hay 3 bytes para mandar por la USART. Z apunta al byte mas significativo.
; La interrupcion, manda un byte, (comenzando por el maas significativo),
; si todavia quedan bytes por mandar, sale sin deshabilitar la interrupcion
; de transmision. Si ya mando los 3, antes de salir la deshabilita.
; ----------------------------------------------------------------------
ISR_REG_USART_VACIO:
	push r16
	ld   r16, Z
	dec  zl
	sts  UDR0, r16
	cpi  zl, 1						;  Z  esta apuntando a r1? Si lo esta haciendo ya se cargaron los 3 bytes
	breq fin
	pop  r16
	reti
fin:
	lds  r16, UCSR0B
	cbr  r16, 1<<UDRIE0
	sts  UCSR0B, r16				; deshabilito interrupciones
	pop  r16
	reti

; ----------------------------------------------------------------------
; DELLAY:
; dellay de 1 segundo para ver mejor los datos enviados.
; ----------------------------------------------------------------------
dellay:
	push r20
	push r21
	push r22

	ldi  r20, 32
L1: ldi  r21,200
L2: ldi  r22, 250	
L3:	
	nop
	nop
	dec  r22
	brne L3

	dec  r21
	brne L2

	dec  r20
	brne L1

	pop  r21
	pop  r22
	pop  r20
	
	ret
	
; ----------------------------------------------------------------------
; SET_TARA:
; Esta funcion lee 16 valores, calcula el promedio y es el ofset que hay que restarle 
; luego a cada dato leido.
; me deja en TARA_H, TARA_L el peso leido inicialmente
; ----------------------------------------------------------------------
	
	.def TARA_H	= r6
	.def TARA_L = r5

	push r16
	push r7

	ldi  r16, 16				; contador
	clr  TARA_L					; LOW_BYTE del resultado
	clr  TARA_H					; HIGH_BYTE del resultado
	clr  r7		
	

loop_tara:
	rcall lectura_peso
	add  TARA_L, DATO_L			; dividir por 8 es shiftear 8 veces a la derecha o directamente agarrar el byte mas dignificativo del peso de 16 bits
	adc  TARA_H, DATO_M
	brcc next
	inc  r7 					; si hubo carry incremento el HIGH_BYTE
next:
	dec  r16
	brne loop_tara
	
division_por_8:
	ldi  r16, 4					; contador con 4 porque se va a shiftear 4 veces
loop_division:
	lsr  r7
	ror  TARA_H
	ror  TARA_L
	dec  r16
	brne  loop_division

	pop r16
	pop r7
	ret

; ----------------------------------------------------------------------
