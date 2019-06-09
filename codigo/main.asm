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
.equ  MULTIPLICADOR = 77			; Factor de multiplicacion de la escala del peso del programa en C ~ 77/2^14

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

.def TARA_H	= r7
.def TARA_M	= r6
.def TARA_L = r5

;-------------------------------------------------------------------------
; codigo
;-------------------------------------------------------------------------
		.cseg 
.org 0x00
	jmp setup

.org	0x0026		; USART Data Register Empty
	jmp	ISR_REG_USART_VACIO


.org 0x500

setup:
	ldi	 r16, HIGH(RAMEND)
	out  sph, r16
	ldi  r16, LOW(RAMEND)
	out  spl, r16					; inicializo el stack pointer al final de la RAM

    rcall configuracion_puertos
	rcall USART_init
	;rcall set_tara
					
	sbi   PORTC, PC2				; encendemos led de prueba
	rcall dellay
	rcall dellay


	jmp main_loop


.org INT_VECTORS_SIZE

main_loop:
	cbi   PORTC, PC2

	rcall lectura_peso				; lee los datos, le resta el tara y los deja almacenados en r4:r2 
    rcall set_scale					; multiplica por el factor de escala para obtener el valor medido en gramos
	rcall dellay
	rcall dellay
	rcall send_data					; Se encarga de activar las interrupciones asi los datos son transmitidos por la UART
 	
	


	jmp main_loop



.org 0x200
;-------------------------------------------------------------------------
; FUNCIONES
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
; CONFIGURACION_PUERTOS:
;-------------------------------------------------------------------------
configuracion_puertos:
	sbi  DDRC, SCK					; puerto PC0 = A0 como salida (SCK)

	sbi  DDRC, PC2					; led de prueba

	cbi  DDRC, DOUT
	sbi  PORTC, DOUT				; puerto PC = A1 como entrada (DOUT)
	ret

;-------------------------------------------------------------------------
; LECTURA_PESO: 
; funcion para la lectura de datos de la celda de carga. Carga
; los bits enviados por el amplificador HX711 a traves del pin DOUT y los
; guarda en los registros r4:r2 y les resta el tara. Usa los registros r16 y r17
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
	sbc   DATO_M, TARA_M
	sbc   DATO_H, TARA_H
	   
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
	breq ISR_REG_USART_VACIO_fin
	pop  r16
	reti
ISR_REG_USART_VACIO_fin:
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

; ----------------------------------------------------------------------
; COM_2:
; Calcula el complemento a dos del dato guardado en  r4:r2 
; ----------------------------------------------------------------------

com_2:
	push  r16
	
	clr r16	
	com DATO_H
	com DATO_M
	neg DATO_L
	brcs com_2_retornar
	adc  DATO_M, r16
	adc  DATO_H, r16

com_2_retornar:
	pop r16
	ret

; ----------------------------------------------------------------------
; SET_TARA:
; Esta funcion lee 16 valores, calcula el promedio y es el offset que hay que restarle 
; luego a cada dato leido.
; me deja en TARA_H, TARA_M, TARA_L el peso leido inicialmente.
; ----------------------------------------------------------------------
set_tara:
	push r16
	push r17
	push r18
	push r19
	push r20

	ldi  r16, 16				; contador, se va a hacer un promedio de 16 muestras para el offset
	clr  TARA_L					
	clr  TARA_M
	clr  TARA_H					
	clr  r17					; 4 bytes para ir guardando la suma parcial del promedio
	clr  r18
	clr  r19		
	clr  r20

set_tara_loop:					
	rcall lectura_peso			
	add  r17, DATO_L			; se usan registros auxiliares para no modificar las lecturas dentro de
	adc  r18, DATO_M			; lectura peso, ya que se resta en esa funcion la tara
	adc  r19, DATO_H
	brcc set_tara_next
	inc  r20 					; si hubo carry incremento el HIGH_BYTE
set_tara_next:
	dec  r16
	brne set_tara_loop

set_tara_division_por_4:	
	ldi  r16, 4					; Para dividir por 16 se crea un contador con 4 porque se va a shiftear 4 veces
set_tara_division:
	lsr  r20
	ror  r19
	ror  r18
	ror  r17
	dec  r16
	brne  set_tara_division
	
	mov TARA_H, r19				; guardo en tara el promedio de los primeros 16 valores
	mov TARA_M, r18
	mov TARA_L, r17
	
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16	
	ret
; ----------------------------------------------------------------------

; ----------------------------------------------------------------------
; SET_SCALE:
; Con los datos de la balanza obtuvimos el factor de escala para pasar
; los datos a gramos. Como el factor es 1/211.9170459 que se aproximó a 77/2^14
; ----------------------------------------------------------------------

set_scale:
	push r16
	push r17
	push r18
	push r19
	push r20

	clr r17
	clr r18
	clr r19
	clr r20
	
	ldi  r16, MULTIPLICADOR
	tst  DATO_H								; si el valor leido es negativo (tara>valor_leido) se le hace el complemento a 2
	brpl multiplicacion_low
	rcall com_2
											; primero multiplicamos por 77 el dato y guardamos el resultado en r20:r17
multiplicacion_low:
	mul  DATO_L, r16						; mutiplico el byte bajo del numero con 3 bytes
	mov  r18, r1
	mov  r17, r0
	
multiplicacion_middle:
	mul  DATO_M, r16						; mutiplico el byte medio del numero con 3 bytes
	add  r18, r0
	adc  r19, r1
	brcc multiplicacion_high
	inc  r20

multiplicacion_high:						; mutiplico el byte alto del numero con 3 bytes
	mul  DATO_H, r16
	add  r19, r0
	adc  r20, r1
											; vamos a dividir por 2^14, que es tomar los primero 3 bytes y shiftear 6 veces
	mov  DATO_L, r18
	mov  DATO_M, r19
	mov  DATO_H, r20

division_por_6:
	ldi  r16, 6

shifteo_loop:
	lsr  DATO_H
	ror  DATO_M
	ror  DATO_L
	dec  r16
	brne shifteo_loop
	
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	ret

		
	
