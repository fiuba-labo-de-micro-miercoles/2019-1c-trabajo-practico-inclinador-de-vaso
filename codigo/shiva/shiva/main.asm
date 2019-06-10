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
.include "hx711.inc"
.include "input.inc"
.include "configuracion.inc"

.org 0x500
.include "hx711.asm"
.include "configuracion.asm"
.include "input.asm"

;-------------------------------------------------------------------------
; VARIABLES EN REGISTROS
;-------------------------------------------------------------------------
.def VASO_H	= r10
.def VASO_M	= r9
.def VASO_L = r8

;-------------------------------------------------------------------------
; CÓDIGO
;-------------------------------------------------------------------------
		.cseg 
.org 0x00
	jmp setup

.org	0x0026		; USART Data Register Empty
	jmp	ISR_REG_USART_VACIO

.org INT_VECTORS_SIZE

setup:
	ldi	 r16, HIGH(RAMEND)
	out  sph, r16
	ldi  r16, LOW(RAMEND)
	out  spl, r16					; inicializo el stack pointer al final de la RAM

    rcall configuracion_puertos
	rcall USART_init
		
	sbi   PORTC, PC2				; encendemos led de prueba
	cbi   PORTC, PC3
	rcall set_tara	
	rcall detectar_perturbacion
	
main_loop:
	cbi   PORTC, PC2	
	sbi   PORTC, PC3	
	rcall lectura_peso				; lee los datos, le resta el tara y los deja almacenados en r4:r2 
	rcall set_scale					; convierte el dato a gramos
	rcall detectar_cancelacion		; chequea si el dato leido es mayor a 4096 gramos, en ese caso cancela el proceso
	rjmp main_loop


;-------------------------------------------------------------------------
; FUNCIONES
;-------------------------------------------------------------------------

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



