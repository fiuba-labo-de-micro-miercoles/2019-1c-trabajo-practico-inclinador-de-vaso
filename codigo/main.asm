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

;-------------------------------------------------------------------------
; variables en SRAM
;-------------------------------------------------------------------------
		.dseg 

;-------------------------------------------------------------------------
; variables en registros
;-------------------------------------------------------------------------
.def  CONT_8 = r18
.def  CONT_3 = r19

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

configuracion_puertos:
	sbi  DDRC, SCK					; puerto PC0 = A0 como salida (SCK)

	cbi  DDRC, DOUT
	sbi  PORTC, DOUT				; puerto PC = A1 como entrada (DOUT)
	

;-------------------------------------------------------------------------
; lectura_peso: funcion para la lectura de datos de la celda de carga. Carga
; los bits enviados por el amplificador HX711 a traves del pin DOUT y los
; guarda en los registros r4:r2
;-------------------------------------------------------------------------
lectura_peso:
	ldi  CONT_3, 3					; el dato ocupa 3 registros
	ldi  zl, LOW(0x05)				; en r4:r2 guardo el dato
	ldi  zh, HIGH(0x05)

	sbic PINC, DOUT					
	rjmp lectura_peso				; chequeo si DOUT está en alto
	nop
	nop 					
	sbic PINC, DOUT					; por la hoja de datos, DOUT debe estar como minimo 0.1 useg en 0
	rjmp lectura_peso				; para indicar que tiene un dato disponible para mandar.

here:
	ldi  CONT_8, 8					; contador para la cantidad de bits por registro
carga_bit:	
	sbi  PORTC, SCK					; genero un flanco ascendente en la señal SCK para cargar un bit
	in   r16, PINC
	bst  r16, DOUT					; en el flag T, tengo un bit del dato
	bld  r17, 0						; lo guardo en LSB de r17
	cbi  PORTC, SCK					; genero un flanco descendente en la señal SCK
	lsl  r17						; shifteo a la izq para dar lugar al proximo bit de dato
	dec  CONT_8
	brne carga_bit
	st   -Z, r17					; Z estaba apuntando inicialmente a r5	
	dec  CONT_3
	brne here						; si no es 0, todavia queda algun byte por cargar
	sbi  PORTC, SCK					; se genera el pulso numero 25 requerido para setear el DOUT
	nop
	nop
	nop
	nop
	cbi  PORTC, SCK
	rjmp lectura_peso
	
	  								
