; ----------------------------------------------------------------------
; DETECTAR_PERTURBACION:
; Para la configuracion del dispositivo se detectaran golpes dados por
; el usuario. Entonces, se determino que un golpe equivale a aproximadamente
; 300 gr. Por lo que se toma el byte del medio del dato y se verifica si es
; mayor a 255. Si lo es se verifica que haya un segundo golpe. Si esto
; ocurre significa que el dispositivo esta siendo configurado.
; ----------------------------------------------------------------------
detectar_perturbacion:
	push  r16
	push  r17

	ldi	  r16, HIGH(MIN_PERTURBACION)					; se utiliza para comparar el valor de lectura y saber si hubo alguna perturbacion
	

detectar_perturbacion_lectura:
	rcall lectura_peso
	rcall set_scale	
	cp    DATO_M, r16
	brlo  detectar_perturbacion_lectura
	ldi   r17, 4

detectar_perturbacion_verificacion:
	dec   r17
	breq  detectar_perturbacion_lectura
	rcall lectura_peso
	rcall set_scale
	cp    DATO_M, r16
	brsh  detectar_perturbacion_verificacion
	ldi   r17, 6

detectar_perturbacion_verificacion2:
	dec   r17
	breq  detectar_perturbacion_lectura
	rcall lectura_peso
	rcall set_scale
	cp    DATO_M, r16
	brlo  detectar_perturbacion_verificacion2
	
	pop   r17
	pop   r16
	ret

; ----------------------------------------------------------------------
; DETECTAR_CANCELACION:
; La cancelacion se da en cualquier momento del proceso cuando el usuario
; hace una presion de mas de 4096 g. Esta funcion chequea el dato leido, 
; lo compara con 4096 g (0x1000) y si es es mayor, espera a que no hay nada  
;  sobre la balanza y vuelve a setup. Se eligio 4096 g porque es solo comparar el segundo
; byte del dato con 0x10 
; ----------------------------------------------------------------------	
detectar_cancelacion:	
	push r16

	mov  r16, DATO_M
	cpi  r16, HIGH (VALOR_CANCELACION)
	brsh proceso_cancelado
	pop  r16
	ret

proceso_cancelado:						
	ldi   zh, HIGH(DIR_MSG_CANCELACION<<1)
	ldi   zl, LOW(DIR_MSG_CANCELACION<<1)
	rcall send_msg
										; se debe volver al SETUP cuando no haya peso sobre la balanza
	cbi    PORTC,PC3					; y eso se dara cuando el dato sea igual al peso del vaso 
										; que quedo guardado en VASO
proceso_cancelado_loop:
	rcall  lectura_peso	
	cp     DATO_H, VASO_H
	brne   proceso_cancelado_loop
	cp     DATO_M, VASO_M
	brne   proceso_cancelado_loop
	ldi    r16, 25
	cp     DATO_L, r16
	brsh   proceso_cancelado_loop
	pop    r16


	rjmp   setup
	
	
