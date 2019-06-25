	.cseg
.org  0x700
	DIR_MSG_INICIO:          .DB "   S.H.I.V.A. ", '\n', "Golpee 2 veces", END_OF_MESSAGE     
	DIR_MSG_ESPERA_VASO:     .DB "Coloque un vaso", END_OF_MESSAGE
	DIR_MSG_AGUARDE:		 .DB "Aguarde... ", END_OF_MESSAGE
	DIR_MSG_CONFIGURACION:   .DB "Elija la medida ", '\n', "con 2 golpes", END_OF_MESSAGE
	
	DIR_MSG_PINTA:           .DB "PINTA (473ml)", '\n', "Golpee para otra.", END_OF_MESSAGE
	MEDIDA_PINTA:			 .DB LOW(473), HIGH(473)

	
	DIR_MSG_CHOPP:           .DB "CHOPP (350ml)", '\n', "Golpee para otra.", END_OF_MESSAGE
	MEDIDA_CHOP:			 .DB LOW(350), HIGH(350)
		
	DIR_MSG_MEDIA_PINTA:     .DB "1/2 PINTA(250ml) ", '\n', "Golpee para otra.", END_OF_MESSAGE 
	MEDIDA_MEDIAPINTA:       .DB LOW(250), HIGH(250), END_OF_MESSAGE, END_OF_MESSAGE, END_OF_MESSAGE, END_OF_MESSAGE

	DIR_MSG_SIRVIENDO:       .DB "Sirva...", '\n', END_OF_MESSAGE
	DIR_MSG_FIN:			 .DB "Puede retirar",'\n', "el vaso", END_OF_MESSAGE
	DIR_MSG_CANCELACION:     .DB "    Proceso ",'\n', "   cancelado", END_OF_MESSAGE 

;-------------------------------------------------------------------------
; DECLINACION_INIT:
; Funcion que setea el servo en la posicion de mayor inclinacion de la
; plataforma. Redefine el Output comapre register para lograr un pwm de 2 ms 
; de tiempo en alto.
;-------------------------------------------------------------------------
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
; función para el proceso de declinación del vaso en base de la cantidad
; de liquido servido. La plataforma (servo) posee 32 posiciones de inclinación y 
; el vaso empieza en la posición 32, y comienza a declinarse cuando
; la cantidad de líquido servida es igual a la mitad de la medida elegida.
; Se define un valor PASO = MEDIDA/64 y un TECHO que arranca en PASO,
; y cada vez que el peso supera el TECHO, se redefine TECHO = TECHO + PASO.
; Cuando el techo es mas grande que la mitad de la MEDIDA se declina el servo cada
; vez que se supera TECHO. 
; Además, por la pantalla se muestra el avance del proceso a medida que se sirve. 
; Para ello, cada cuatro incrementos del TECHO, se envia un caracter negro a la pantalla.
;-------------------------------------------------------------------------


proceso_declinacion:
	push  r16
	push  MEDIDA_MITAD_L
	push  MEDIDA_MITAD_H
	push  TECHO_L
	push  TECHO_H
	push  PASO

	mov   MEDIDA_MITAD_L, MEDIDA_L					; obtenemos la mitad de la medida que es cuando se comienza a declinar el vaso
	mov   MEDIDA_MITAD_H, MEDIDA_H
	lsr   MEDIDA_MITAD_H							
	ror   MEDIDA_MITAD_L							

	mov   PASO, MEDIDA_MITAD_L						; se divide el rango de valores que va desde MEDIDA/2 HASTA MEDIDA,
	lsr   PASO										; por 32, que son las cantidad de posiciones que tiene la paltaforma.
	lsr   PASO										; que equivale a divir el valor de la MEDIDA por 64.
	lsr   PASO
	lsr   PASO
	lsr   PASO

	clr  TECHO_H									
	clr  TECHO_L

proceso_declinacion_loop:
	ldi   r16, 4									; contador para enviar caracteres que indican el avance del proceso

proceso_declinacion_techo:
	add   TECHO_L, PASO								; defino el techo como TECHO = TECHO + PASO
	brcc  proceso_declinacion_techo_next
	inc   TECHO_H

proceso_declinacion_techo_next:
	cp    MEDIDA_H, TECHO_H 						; si MEDIDA_H < TECHO_H ==> MEDIDA < TECHO entonces se termina el proceso
	brlo  proceso_declinacion_fin
	
	cp    TECHO_H, MEDIDA_H							; ya se que MEDIDA_H >= TECHO_H, asi que verifico si se cumple la igualdad o el techo es mayor 
	brlo  proceso_declinacion_lectura
	
	cp    TECHO_L, MEDIDA_L							; si esta aca MEDIDA_H = TECHO_H
	brsh  proceso_declinacion_fin					; si TECHO_L > MEDIDA_L => TECHO > MEDIDA y termina el proceso

proceso_declinacion_lectura:
	rcall lectura_peso								; se lee un dato y se escala
	rcall set_scale
	rcall detectar_cancelacion

	cp    DATO_M, TECHO_H							; se compara el valor leido con el techo
	brlo  proceso_declinacion_lectura				; mientras el dato sea menor que el techo se sigue leyendo 
	cp    DATO_L, TECHO_L
	brlo  proceso_declinacion_lectura
	
	cp    MEDIDA_MITAD_H, TECHO_H					; se compara el dato leido con la mitad de la medida para 
	brlo  proceso_declinacion_servo					; ver si se tiene que declinar la plataforma
	cp    TECHO_L, MEDIDA_MITAD_L
	brlo  proceso_declinacion_step

proceso_declinacion_servo:
	rcall mover_servo
	 
proceso_declinacion_step:
	dec   r16										; si se incrementó 4 veces el TECHO, envía el caracter en negro 
	brne  proceso_declinacion_techo
	rcall send_black_char
	rjmp  proceso_declinacion_loop

proceso_declinacion_fin:
	rcall servo_init								; cuando se llego a la medida seleccionada se lleva el servo a la posición final
													; en caso que haya faltado algun decremento de la plataforma
	pop   PASO
	pop   TECHO_H
	pop   TECHO_L
	pop   MEDIDA_MITAD_H
	pop   MEDIDA_MITAD_L
	pop   r16
	ret
;-------------------------------------------------------------------------
; MOVER_SERVO:
; Decrementa en uno la posición actual del servo y con eso, la de la plataforma.
;-------------------------------------------------------------------------
mover_servo:
	push  r16
	push  r17

	lds   r16, OCR1AL								; cuando el valor leido es mayor al techo se decrementa la posición del servo
	lds   r17, OCR1AH								; decrementando el Output Compare Register y achicando asi el pulso del PWM
	
	subi  r16, 0x01								
	brcc  mover_servo_next
	dec   r17

mover_servo_next:
	cpi   r17, HIGH(313+8)							; por seguridad se compara la nueva posición con la mínima posición posible del servo
	brlo  mover_servo_fin							; si es mas chica salgo de la función
	cpi   r16, LOW(313+8)
	brlo  mover_servo_fin

	sts   OCR1AH, r17								
	sts   OCR1AL, r16

mover_servo_fin:
	pop  r17
	pop  r16
	ret

;-------------------------------------------------------------------------
; SEND_COMMAND:
; Recibe el registro r16 cargado con una configuración. Luego
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
; lo envía por la pantalla LCD. Los mensajes tienen un formato definido,
; terminan con END_OF_MESSAGE y si son de dos líneas, la separación entre ellas se indica
; con el caracter '\n'.
;-------------------------------------------------------------------------
send_msg:
	push  r16
	push  r17

	ldi   r16, CLEAR_DISPLAY	; Borra la pantalla
	rcall send_command			
	rcall delay_3ms

send_msg_loop:
    lpm  r16, Z+
	
	cpi  r16, END_OF_MESSAGE	; Me fijo si terminó el mensaje
	breq send_msg_fin
	cpi  r16, '\n'				; Me fijo si el mensaje tiene una segunda parte
	brne send_msg_next

	ldi   r16, CURSOR_LINE_2	; Fuerza el cursor a la 2da línea
	rcall send_command			
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
	