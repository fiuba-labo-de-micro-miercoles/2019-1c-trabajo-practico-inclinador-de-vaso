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

.equ  MULTIPLICADOR = 141		; Factor de multiplicacion de la escala del peso (1/6872 ~ 19/2^17)
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

.def TARA_H	= r6
.def TARA_L = r5

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
			
	rcall set_tara
	
	; Hardcodeo del valor inicial leido---------------
	; ldi  r16, LOW(0x125)
	; mov  TARA_L, r16
	; ldi  r16, HIGH(0x125)
	; mov  TARA_H, r16
	; ------------------------------------------------

here:
	rcall lectura_peso				; lee los datos y los deja almacenados en r4:r2
	; rcall dellay
	; rcall dellay
	rcall send_data					; Se encarga de activar las interrupciones asi los datos son transmitidos por la UART
	; rcall dellay
	; rcall dellay
 
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

lectura_peso_loop:
	sbic  PINC, DOUT					
	rjmp  lectura_peso_loop			; chequeo si DOUT está en alto
	nop							
	nop 							; Espero dos ciclos y vuelvo a preguntar si sigue en alto ya que
	sbic  PINC, DOUT				; por la hoja de datos, DOUT debe estar como minimo 0.1 useg en 0
	rjmp  lectura_peso_loop			; para indicar que tiene un dato disponible para mandar.

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
	
	rcall com_2						; Hace el complemento a 2 de los datos leidos
	
	sub   DATO_L, TARA_L			; Le saco el offset a los valores
	sbc   DATO_M, TARA_H

	pop   r17
	pop   r16
	ret

cargar_byte:
	clr   r16
	ldi   CONT_8, 8
cargar_bit:
	sbi   PORTC, SCK				; se genera un flanco ascendente en la señal SCK para cargar un bit
	nop
	nop
	nop
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
	ldi  zh, HIGH(0x04)				; hay que mandar 3 bytes, ubicados en r4:r2. Definimos
	ldi  zl, LOW(0x04)				; que Z apunte a r4 y luego en la rutina de interruopcion se decrementa
	
	lds  r16, UCSR0B
	sbr  r16, 1<<UDRIE0
	sts  UCSR0B, r16				; habilito interrupciones 
	sei
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
	
	pop  r22
	pop  r21
	pop  r20
	
	ret

; ----------------------------------------------------------------------
; COM_2:
; Elimina el byte menos significativo y hace el complemento a dos 
; de los otros dos bytes y los deja en r3:r2 y clr r4. 
; ----------------------------------------------------------------------

com_2:

	mov  DATO_L, DATO_M
	mov  DATO_M, DATO_H
	clr  DATO_H
	
	com DATO_M
	neg DATO_L
	brcs com_2_retornar
	inc DATO_M
com_2_retornar:
	ret
; ----------------------------------------------------------------------
; SET_SCALE:
; Con los datos de la balanza obtuvimos el factor de escala para pasar
; los datos a gramos. Como el factor es 1/6872 que se aproximó a 19/2^17
; ----------------------------------------------------------------------

/*set_scale:
	push r16
	push r17
	push r18
	push r19
	
	ldi r17, 7
	ldi r16, MULTIPLICADOR

shifteo:
	pop r19
	pop r18
	pop r17
	pop r16
	ret

	lsr  DATO_M
	ror  DATO_L
	dec  r17
	brne shifteo


multiplicacion_low:
	
	mul  DATO_L,r16						; mutiplico el byte bajo del numero con 2 bytes
	mov  r18, r1
	mov  r17, r0
	
multiplicacion_high:
	mul  DATO_M, r16
	mov  r19, r1
	add  r18, r0
	brcc here_scale
	inc   r19
		
here_scale:
	mov  DATO_L, r17
	mov  DATO_M, r18
	mov  DATO_H, r19
	
	;lsr  DATO_M
	;ldi  r16, MULTIPLICADOR
	;mul  DATO_M, r16								; Multiplicacion por 19
	;mov  DATO_L, r0									
	;mov  DATO_M, r1									; Se guarda el resultado de la multiplicacion en r3:r2
	
	pop r19
	pop r18
	pop r17
	pop r16
	ret
	
	; ror  DATO_L
	;dec  r16
	; brne shifteo
	;pop r16
	;ret
	

	lsr  DATO_H										; Como hay que dividir por 2^17 simplemente se shiftea a la derecha el byte
	neg  DATO_H										; mas significativo y luego se toma el complemento a 2.
	
	mul	 DATO_H, r16								; Multiplicacion por 19
	

	mov  DATO_L, r0									
	mov  DATO_M, r1									; Se guarda el resultado de la multiplicacion en r3:r2

	clr  r16
	mov  DATO_H, r16								; El byte mas significativo se setea en 0

	pop r16
	ret
	*/

; ----------------------------------------------------------------------
; SET_TARA:
; Esta funcion lee 16 valores, calcula el promedio y es el ofset que hay que restarle 
; luego a cada dato leido.
; me deja en TARA_H, TARA_L el peso leido inicialmente
; ----------------------------------------------------------------------
set_tara:
	push r16
	push r17
	push r18
	push r19

	ldi  r16, 16				; contador
	clr  TARA_L					; LOW_BYTE del resultado
	clr  TARA_H					; HIGH_BYTE del resultado
	clr  r17
	clr  r18
	clr  r19		
	
set_tara_loop:
	rcall lectura_peso
	add  r17, DATO_L			
	adc  r18, DATO_M
	brcc set_tara_next
	inc  r19 					; si hubo carry incremento el HIGH_BYTE
set_tara_next:
	dec  r16
	brne set_tara_loop
	
	ldi  r16, 4					; division por 16. Contador con 4 porque se va a shiftear 4 veces
set_tara_division:
	lsr  r19
	ror  r18
	ror  r17
	dec  r16
	brne  set_tara_division
	
	mov TARA_H, r18				; guardo en tara el promedio de los primeros 16 valores
	mov TARA_L, r17
	
	pop r19
	pop r18
	pop r17
	pop r16	
	ret
; ----------------------------------------------------------------------

