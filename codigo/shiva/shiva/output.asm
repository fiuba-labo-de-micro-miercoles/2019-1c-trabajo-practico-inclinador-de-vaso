	.cseg
.org  0x700
	DIR_MSG_INICIO:          .DB "   S.H.I.V.A. ", '\n', "Golpee 2 veces", 0xFF     
	DIR_MSG_ESPERA_VASO:     .DB "Coloque un vaso", 0xFF
	DIR_MSG_CONFIGURACION_1: .DB "Golpear 2 veces", '\n', "para elegir vaso", 0xFF, 0xFF
	DIR_MSG_PINTA:           .DB "PINTA (500ml)", '\n', "Golpee para otro", 0xFF, 0xFF
	DIR_MSG_CHOPP:           .DB "CHOPP (375ml)", '\n', "Golpee para otro", 0xFF, 0xFF
	DIR_MSG_MEDIA_PINTA:     .DB "1/2 PINTA (250ml)", '\n', "Golpee para otro", 0xFF, 0xFF
	DIR_MSG_SIRVIENDO:       .DB "Sirviendo....", 0xFF
	DIR_MSG_CANCELACION:     .DB "    Proceso",'\n', "   cancelado", 0xFF, 0xFF

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
	
	cpi r16, 0xFF				; Me fijo si termino el mensaje
	breq send_msg_fin
	cpi r16, '\n'				; Me fijo si el mensaje tiene una segunda parte
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
	pop  r16
	pop  r17
	ret
