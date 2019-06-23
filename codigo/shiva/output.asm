	.cseg
.org  0x700
	DIR_MSG_INICIO:          .DB "   S.H.I.V.A. ", '\n', "Golpee 2 veces", 0xFF     
	DIR_MSG_ESPERA_VASO:     .DB "Coloque un vaso", 0xFF
	DIR_MSG_AGUARDE:		 .DB "Aguarde... ", 0xFF
	DIR_MSG_CONFIGURACION:   .DB "Elija la medida ", '\n', "golpeando x2", 0xFF
	
	DIR_MSG_PINTA:           .DB "PINTA (500ml)", '\n', "Golpee para otro.", 0xFF
	MEDIDA_PINTA:			 .DB LOW(500), HIGH(500)

	
	DIR_MSG_CHOPP:           .DB "CHOPP (375ml)", '\n', "Golpee para otro.", 0xFF
	MEDIDA_CHOP:			 .DB LOW(375), HIGH(375)

	
	DIR_MSG_MEDIA_PINTA:     .DB "1/2 PINTA(250ml) ", '\n', "Golpee para otro ", 0xFF 
	MEDIDA_MEDIAPINTA:       .DB LOW(250), HIGH(250), 0xFF, 0xFF, 0xFF, 0xFF

	DIR_MSG_SIRVIENDO:       .DB "Puede servir...", 0xFF
	DIR_MSG_FIN:			 .DB "Puede retirar",'\n', "el vaso", 0xFF
	DIR_MSG_CANCELACION:     .DB "    Proceso ",'\n', "   cancelado", 0xFF 

;-------------------------------------------------------------------------
; DECLINACION_INIT:
; Funcion que setea el servo en la posicion de amyor inclinacion de la
; plataforma
;-------------------------------------------------------------------------
.equ  POS_MAYOR_INCLINACION = 313 + 40			; valor para el Output Comapre Register para posicionar el servo en la mayor inclinacion

declinacion_init:
	push r16
	
	ldi  r16, HIGH(POS_MAYOR_INCLINACION)
	sts  OCR1AH, r16

	ldi  r16, LOW(POS_MAYOR_INCLINACION)
	sts  OCR1AL, r16

	pop  r16
	ret

;-------------------------------------------------------------------------
; PROCESO_DECLINACION:
; funcion para el proceso de declinacion del vaso en funcion de la cantidad
; de liquido servido. La plataforma posee 32 posiciones de inclinacion y 
; el vaso comienza en la posicion 32, y comienza a declinarse cuando
; la cantidad de liquido servida es igual a la mitad de la medida elegida.
;-------------------------------------------------------------------------
.def   TECHO_L = r20
.def   TECHO_H = r21
.def   PASO = r22

proceso_declinacion:
	push  r16
	push  r17
	push  TECHO_L
	push  TECHO_H
	push  PASO

	mov   TECHO_L, MEDIDA_L
	mov   TECHO_H, MEDIDA_H
	lsr   TECHO_H									; dividimos la medida por 2
	ror   TECHO_L									; en r16 ya va a quedar la mitad de la medida
	
	mov   PASO, TECHO_L								; se divide el rango de valores que va desde MEDIDA/2 HASTA MEDIDA,
	lsr   PASO										; por 32, que son las cantidad de posiciones que tiene la paltaforma.
	lsr   PASO									
	lsr   PASO
	lsr   PASO
	lsr   PASO

proceso_declinacion_lectura:
	rcall lectura_peso								; se lee un dato
	rcall set_scale
	rcall detectar_cancelacion

	cp    DATO_M, TECHO_H							; se compara el valor leido con el techo
	brlo  proceso_declinacion_lectura				; mientras el dato sea menor que el techo se sigue leyendo
	cp    DATO_L, TECHO_L
	brlo  proceso_declinacion_lectura

	lds   r16, OCR1AL								; cuando el valor leido es mayor al techo se decrementa la posicion del servo
	lds   r17, OCR1AH								; decrementando el Output Compare Register y achicando asi el pulso del PWM
	
	subi  r16, 0x01								
	brcc  proceso_declinacion_next2
	dec   r17

	cpi   r16, 0x08
	brlo  proceso_declinacion_fin

proceso_declinacion_next2:
	sts   OCR1AH, r17								
	sts   OCR1AL, r16

	add   TECHO_L, PASO								; se define el nuevo techo como TECHO = TECHO + PASO
	brcc  proceso_declinacion_next
	inc   TECHO_H

proceso_declinacion_next:
	cp    TECHO_H, MEDIDA_H							; se verifica que el valor leido no sea mayor que la medida seleccionada
	brlo  proceso_declinacion_lectura
	cp    TECHO_L, MEDIDA_L
	brlo  proceso_declinacion_lectura

proceso_declinacion_fin:
	rcall servo_init								; cuando se llego a la medida seleccionada se lleva el servo a la posicion final

	pop   PASO
	pop   TECHO_H
	pop   TECHO_L
	pop   r17
	pop   r16
	ret
;-------------------------------------------------------------------------
; SEND_COMMAND:
; Recibe el registro r16 cargado con una configuracion. Luego
; lo envía a la pantalla LCD.
;-------------------------------------------------------------------------
send_command:
	push  r17

	mov   r17, r16				; se mandan los 4 bits mas significativos primero
	andi  r17, 0xF0
	out   LCD_DPRT, r17
	cbi   LCD_CPRT, LCD_RS		; RS = 0 es para mandar comandos
	cbi   LCD_CPRT, LCD_RW
	sbi   LCD_CPRT, LCD_E
	rcall delay_500ns 
	cbi   LCD_CPRT,LCD_E

	mov   r17, r16				; ahora los 4 bits restantes
	swap  r17
	andi  r17, 0xF0
	out   LCD_DPRT, r17
	cbi   LCD_CPRT, LCD_RS		; RS = 0 es para mandar comandos
	cbi   LCD_CPRT, LCD_RW
	sbi   LCD_CPRT, LCD_E
	rcall delay_500ns 
	cbi   LCD_CPRT,LCD_E

	rcall delay_100us
	pop  r17
	ret
;-------------------------------------------------------------------------
; SEND_MSG:
; Recibe el puntero Z cargado con un mensaje guardado en memoria ROM. Luego
; lo envía por la pantalla LCD.
;-------------------------------------------------------------------------
send_msg:
	push  r16
	push  r17

	ldi   r16, CLEAR_DISPLAY
	rcall send_command			; Borra la pantalla
	rcall delay_3ms

send_msg_loop:
    lpm  r16, Z+
	
	cpi  r16, 0xFF				; Me fijo si termino el mensaje
	breq send_msg_fin
	cpi  r16, '\n'				; Me fijo si el mensaje tiene una segunda parte
	brne send_msg_next

	ldi   r16, CURSOR_LINE_2
	rcall send_command			; Fuerza el cursor a la 2da linea
	rcall delay_3ms	
	rjmp  send_msg_loop

send_msg_next:	
	mov   r17, r16				; se mandan los 4 bits mas significativos primero
	andi  r17, 0xF0
	out   LCD_DPRT, r17
	sbi   LCD_CPRT, LCD_RS		; RS = 1 es para mandar datos
	cbi   LCD_CPRT, LCD_RW
	sbi   LCD_CPRT, LCD_E
	rcall delay_500ns 
	cbi   LCD_CPRT,LCD_E

	mov   r17, r16				; ahora los 4 bits restantes
	swap  r17
	andi  r17, 0xF0
	out   LCD_DPRT, r17
	sbi   LCD_CPRT, LCD_RS		; RS = 1 es para mandar datos
	cbi   LCD_CPRT, LCD_RW
	sbi   LCD_CPRT, LCD_E
	rcall delay_500ns 
	cbi   LCD_CPRT,LCD_E
	rcall delay_100us
	rjmp  send_msg_loop
send_msg_fin:		
	pop  r17
	pop  r16
	ret