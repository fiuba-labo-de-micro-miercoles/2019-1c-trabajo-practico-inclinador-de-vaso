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
.org	0x00
	jmp setup

.org	OVF1addr
	jmp INT_TIMER1_OVF

.org   OVF0addr
	jmp INT_TIMER0_OVF

.org INT_VECTORS_SIZE

setup:
	ldi	 r16, HIGH(RAMEND)
	out  sph, r16
	ldi  r16, LOW(RAMEND)
	out  spl, r16								; inicializo el stack pointer al final de la RAM
    
	sei

	rcall configuracion_puertos
	rcall servo_init
	rcall LCD_init

	clr   VASO_H
	clr   VASO_M
	clr   VASO_L
	
	ldi   zh, HIGH(DIR_MSG_AGUARDE<<1)			; Se envia el mensaje de aguarde hasta que se termina de configurar el peso con la tara
	ldi   zl, LOW(DIR_MSG_AGUARDE<<1)
	rcall send_msg

	rcall set_tara								; Setea el peso 0 de la balanza
	
	ldi   zh, HIGH(DIR_MSG_INICIO<<1)			; se envia el mensaje de inicio
	ldi   zl, LOW(DIR_MSG_INICIO<<1)
	rcall send_msg

	;rcall detectar_perturbacion				; espera a que haya una perturbación para iniciar el proceso
	
	ldi   zh, HIGH(DIR_MSG_ESPERA_VASO<<1)		; mensaje hasta que se detecta un peso que equivale a un vaso
	ldi   zl, LOW(DIR_MSG_ESPERA_VASO<<1)
	rcall send_msg
	
	
	rcall detectar_vaso
	ldi   zh, HIGH(DIR_MSG_CONFIGURACION<<1)	; mensaje para elegir medida
	ldi   zl, LOW(DIR_MSG_CONFIGURACION<<1)
	rcall send_msg
	rcall delay_3seg							; se muestra el mensaje durante 3 segundos
	
	rcall configurar_medida
	
	ldi   zh, HIGH(DIR_MSG_AGUARDE<<1)			
	ldi   zl, LOW(DIR_MSG_AGUARDE<<1)
	rcall send_msg

	rcall declinacion_init						; inclina la plataforma a la posicion inicial
	
	ldi   zh, HIGH(DIR_MSG_SIRVIENDO<<1)		; mensaje que le indica al usuario que le puede comenzar a servir
	ldi   zl, LOW(DIR_MSG_SIRVIENDO<<1)
	rcall send_msg
	
	rcall proceso_declinacion   
	
	ldi   zh, HIGH(DIR_MSG_FIN<<1)				; mensaje que le indica al usuario que puede retirar el vaso
	ldi   zl, LOW(DIR_MSG_FIN<<1)
	rcall send_msg
	
	rcall fin_programa							; aguarda a que retiren el vaso 
	 
	rjmp setup

;-------------------------------------------------------------------------
; FUNCIONES
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
; SEND_BLACK_CHAR:
; manda un caracter en negro cuyo valor ASCII es 0xFF.
;-------------------------------------------------------------------------
send_black_char:
	push  r17

	ldi   r17, 0xFF					; se mandan los 4 bits mas significativos primero
	andi  r17, 0xF0
	out   LCD_DPRT, r17
	sbi   LCD_CPRT, LCD_RS			; RS = 1 es para mandar datos
	cbi   LCD_CPRT, LCD_RW
	sbi   LCD_CPRT, LCD_E
	rcall delay_500ns 
	cbi   LCD_CPRT,LCD_E

	ldi   r17, 0xFF					; ahora los 4 bits restantes
	swap  r17
	andi  r17, 0xF0
	out   LCD_DPRT, r17
	sbi   LCD_CPRT, LCD_RS			; RS = 1 es para mandar datos
	cbi   LCD_CPRT, LCD_RW
	sbi   LCD_CPRT, LCD_E
	rcall delay_500ns 
	cbi   LCD_CPRT,LCD_E

	rcall delay_100us
	pop  r17
	ret
	
;-------------------------------------------------------------------------
; INT_TIMER1_0VF:
; rutina de interrupcion vinculada al Timer1, que controla el pwm del servo.
;-------------------------------------------------------------------------
INT_TIMER1_OVF:
	push r16

	ldi  r16, HIGH(313)
	sts  TCNT1H, r16
	ldi  r16, LOW(313)
	sts  TCNT1L, r16

	pop  r16
	reti

;-------------------------------------------------------------------------
; INT_TIMER0_OVF:
; rutina de interrupcion vinculada al Timer1, que controla el delay de los 4
; segundos que posee el usuario para ir cambiando de medida
;-------------------------------------------------------------------------
INT_TIMER0_OVF:
	dec  r23
	brne int_next								; hasta que el contador no llega a 0 no pasaron los 4 segundos
	set											; se activa el flag T para salir de la funcion detectar_perturbacion cuando pasaron los 4 segundos										
int_next:	
	reti

; ----------------------------------------------------------------------
; DELAY_3seg:
; Delay de 3 segundos 
; ----------------------------------------------------------------------
delay_3seg:
	push r16

	ldi r16, 0
	out TCNT0, r16					; se inicializa el contador
	
	clr r16
	out TCCR0A, r16		
	
	ldi r16, (1<<CS02)|(0<<CS01)|(1<<CS00)
	out TCCR0B, r16					; config: modo normal, con prescaler = 1024

	ldi r16, 184
delay_3seg_loop:
	sbis TIFR0, TOV0
	rjmp delay_3seg_loop
	sbi  TIFR0, TOV0				; se setea el flag TOV0 para dejarlo en 0
	dec  r16
	brne delay_3seg_loop
	clr  r16
	out  TCCR0B, r16				; se apaga el timer
	sbi  TIFR0, TOV0				; se setea el flag TOV0 para dejarlo en 0

	pop r16
	ret	
; ----------------------------------------------------------------------
; DELAY_500ns:
; Delay de 500ns 
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
; DELAY_3ms:
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

	clr   r16
	out   TCCR0A, r16					; config: modo normal, OC0A y OC0B desconectados 
	
	ldi   r16, (1<<CS02)|(0<<CS01)|(1<<CS00)
	out   TCCR0B, r16					; config: modo normal, con prescaler = 1024

	ldi  r16, (1<<TOIE0)				; se activa la interrupcion por overflow
	sts  TIMSK0, r16

	ldi  r23, 244						; se inicializa el contador para el delay de 4 s
	
	sei 
	
	pop  r16
	ret




