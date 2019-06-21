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
.include "output.inc"

.org 0x500
.include "hx711.asm"
.include "configuracion.asm"
.include "input.asm"
.include "output.asm"

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

.org    0x0020
	jmp INT_TIMER0_OVF

.org	0x0026								; USART Data Register Empty
	jmp	ISR_REG_USART_VACIO

.org INT_VECTORS_SIZE

setup:
	ldi	 r16, HIGH(RAMEND)
	out  sph, r16
	ldi  r16, LOW(RAMEND)
	out  spl, r16								; inicializo el stack pointer al final de la RAM

    rcall configuracion_puertos
	rcall USART_init
	rcall LCD_init

	ldi   zh, HIGH(DIR_MSG_AGUARDE<<1)			; Se envia el mensaje de aguarde hasta que se termina de configurar el peso con la tara
	ldi   zl, LOW(DIR_MSG_AGUARDE<<1)
	rcall send_msg

	sbi   PORTC, PC2							; encendemos led de prueba
	cbi   PORTC, PC3
	rcall set_tara								; Setea el peso 0 de la balanza
	
	ldi   zh, HIGH(DIR_MSG_INICIO<<1)			; Se envia el mensaje de inicio
	ldi   zl, LOW(DIR_MSG_INICIO<<1)
	rcall send_msg

	rcall detectar_perturbacion					; Esta función espera a que haya una perturbación para iniciar el proceso
	
	ldi   zh, HIGH(DIR_MSG_ESPERA_VASO<<1)		; Mensaje hasta que se detecta un peso
	ldi   zl, LOW(DIR_MSG_ESPERA_VASO<<1)
	rcall send_msg
	
	rcall detectar_vaso
	ldi   zh, HIGH(DIR_MSG_CONFIGURACION_1<<1)	; Mensaje para elegir medida
	ldi   zl, LOW(DIR_MSG_CONFIGURACION_1<<1)
	rcall send_msg

main_loop:
	cbi   PORTC, PC2							; LEDS de prueba	
	sbi   PORTC, PC3	
	rcall lectura_peso							; lee los datos, le resta el tara y los deja almacenados en r4:r2 
	rcall set_scale								; convierte el dato a gramos
	rcall detectar_cancelacion					; chequea si el dato leido es mayor a 4096 gramos, en ese caso cancela el proceso
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
	ld   r16, Y
	dec  yl
	sts  UDR0, r16
	cpi  yl, 1						;  Z  esta apuntando a r1? Si lo esta haciendo ya se cargaron los 3 bytes
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
; Delay de 500ns porque el pin E tiene que estar alto ese tiempo
; ----------------------------------------------------------------------
delay_500ns:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ret

; -------------------------------------------------------------------------
; DELAY_100us:
; funcion de delay de 100 us. 
; Calculo de delay: (256-VALOR_INICIAL_TCNT0) * PRESCALER / fclk
; -------------------------------------------------------------------------

delay_100us:
	push r16

	ldi r16, 248
	out TCNT0, r16					; se inicializa el contador
	
	clr r16
	out TCCR0A, r16		
	
	ldi r16, (1<<CS02)|(0<<CS01)|(0<<CS00)
	out TCCR0B, r16					; config: modo normal, con prescaler = 256
delay_100us_loop:
	sbis TIFR0, TOV0
	rjmp delay_100us_loop
	clr  r16
	out  TCCR0B, r16				; se apaga el timer
	sbi  TIFR0, TOV0				; se setea el flag TOV0 para dejarlo en 0

	pop r16
	ret

; -------------------------------------------------------------------------
; DELAY_3MS:
; funcion de delay de 3 ms. 
; Calculo de delay: (256-VALOR_INICIAL_TCNT0) * PRESCALER / fclk
; -------------------------------------------------------------------------
delay_3ms:
	push r16

	ldi r16, 69
	out TCNT0, r16					; se inicializa el contador
	
	clr r16
	out TCCR0A, r16		
	
	ldi r16, (1<<CS02)|(0<<CS01)|(0<<CS00)
	out TCCR0B, r16					; config: modo normal, con prescaler = 256
delay_3ms_loop:
	sbis TIFR0, TOV0
	rjmp delay_3ms_loop
	clr  r16
	out  TCCR0B, r16				; se apaga el timer
	sbi  TIFR0, TOV0				; se setea el flag TOV0 para dejarlo en 0

	pop r16
	ret

; -------------------------------------------------------------------------
; DELAY_4s:
; funcion que activa un delay de 4 seg, que es el tiempo que tendra el 
; usuario para ir cambiando de medida de vaso.
; -------------------------------------------------------------------------
delay_4s:
	push  r16

	clr   r16							
	out   TCNT0, r16					; se inicializa el contador en 0 	

	out   TCCR0A, r16					; config: modo normal, OC0A y OC0B desconectados
	
	ldi   r16, (1<<CS02)|(0<<CS01)|(1<<CS00)
	out   TCCR0B, r16					; config: modo normal, con prescaler = 1024

	ldi  r16, (1<<TOIE0)				; se activa la interrupcion por overflow
	sts  TIMSK0, r16

	ldi  r18, 244						; se inicializa el contador para el delay de 4 s
	pop  r16
	ret

;-------------------------------------------------------------------------
; DETECTA_VASO:
; Se tiene en cuenta que un vaso de virdio pesa aproximadamente 200gr. 
; La funcion lee un dato y compara con el valor minimo de un vaso, 
; cuando detecta este valor se fija que en la siguiente lectura
; el valor sea el mismo. Guarda ese valor en VASO_H VASO_L y setea la tara. 
;-------------------------------------------------------------------------
.equ VASO_MINIMO = 200

detectar_vaso: 
	push  r16

	ldi   r16, VASO_MINIMO				; peso aproximado de un vaso de vidrio

detectar_vaso_lectura:
	rcall lectura_peso					
	rcall set_scale						; lee un dato y lo escala
	rcall detectar_cancelacion
	tst   DATO_H						
	brne  detectar_vaso_verificacion					
	cp    DATO_L, r16					; compara el peso leido con el peso estandar de un vaso			
	brlo  detectar_vaso_lectura			; si no detecta un cambio vuelve a leer un peso
	

detectar_vaso_verificacion:				; la balanza envia 10 muestras por segundo por lo que la siguiente muestra sera a los 10 ms de la anterior
	mov   VASO_L, DATO_L
	mov   VASO_H, DATO_H
	rcall lectura_peso					
	rcall set_scale						; lee un dato y lo escala
	rcall detectar_cancelacion
	cp    DATO_H, VASO_H				; compara el peso leido con el peso estandar de un vaso			
	brne  detectar_vaso_lectura		
	cp    DATO_L, VASO_L				; compara el peso leido con el peso estandar de un vaso			
	brne  detectar_vaso_lectura	
	
	ldi   zh, HIGH(DIR_MSG_AGUARDE<<1)	; Mensaje hasta que se setea la tara
	ldi   zl, LOW(DIR_MSG_AGUARDE<<1)
	rcall send_msg

	rcall set_tara						; setea la tara ahora con el vaso puesto
	
	pop   r16
	ret

;-------------------------------------------------------------------------
; CONFIGURAR_MEDIDA:
; Se espera 3 segundos a que el usuario golpee 2 veces para cambiar la medida
;-------------------------------------------------------------------------


.def    MEDIDA_L = r11
.def    MEDIDA_H = r12

configurar_medida:
	push r16
	push r17
	push r18
	push zl
	push zh

	ldi  r17, 0xFF

configurar_medida_init:
	ldi  zl, LOW(MEDIDA_PINTA<<1)				; Se inicializa en la medida pinta
	ldi  zh, HIGH(MEDIDA_PINTA<<1)

configurar_medida_loop:
	lpm  MEDIDA_L, Z+					; se guarda la medida seleccionada
	lpm  MEDIDA_H, Z+ 
	
	cp   MEDIDA_L, r17					; si el siguiente valor es 0xFF, ya se recorrieron las 3 medidas
	breq configurar_medida_init
	
	rcall send_msg						; envia el mensaje correspondiente a la medida cargada
		
	rcall delay_4s						; inicializa el delay de 4 seg
	
	rcall detectar_perturbacion			
	
	ldi  r16, (1<<TOIE0)				; se desactiva la interrupcion por overflow
	sts  TIMSK0, r16
	rjmp  configurar_medida_loop

configurar_medida_fin:					; si pasaron 4 seg, de la subrutina de interrupcion se vuelve aqui
	ldi   r16, (0<<CS02)|(0<<CS01)|(0<<CS00)
	out   TCCR0B, r16					; config: se apaga el timer

	ldi  r16, (0<<TOIE0)				; se desactiva la interrupcion por overflow
	sts  TIMSK0, r16
	
	sei								

	pop   zh
	pop   zl
	pop   r18
	pop   r17
	pop   r16
	ret	


;-------------------------------------------------------------------------
; INT_TIMER0_OVF:
; 
;-------------------------------------------------------------------------
INT_TIMER0_OVF:
	dec  r18
	breq configurar_medida_fin					; si el contador llego a 0, pasaron 4 segundos
	reti










