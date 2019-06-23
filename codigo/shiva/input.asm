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
	brts  detectar_perturbacion_fin
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

detectar_perturbacion_fin:
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
	ldi    r17, 2									; y eso se dara cuando el dato sea igual al peso del vaso 
	ldi    r16, 10						; que quedo guardado en VASO
proceso_cancelado_loop:
	rcall  lectura_peso	

	sub    DATO_L, VASO_L
	sbc    DATO_M, VASO_M
	sbc	   DATO_H, VASO_H
	brsh   proceso_cancelado_next
	rcall  com_2
proceso_cancelado_next:	
	tst    DATO_H
	brne   proceso_cancelado_loop
	tst    DATO_M
	brne   proceso_cancelado_loop
	cp     DATO_L, r16
	brsh   proceso_cancelado_loop
	dec    r17
	brne   proceso_cancelado_loop
	/*cp     DATO_H, VASO_H
	brne   proceso_cancelado_loop
	cp     DATO_M, VASO_M
	brne   proceso_cancelado_loop
	cp     DATO_L, VASO_L
	brne   proceso_cancelado_loop*/
	pop    r16
	rjmp   setup

;-------------------------------------------------------------------------
; DETECTA_VASO:
; Se tiene en cuenta que un vaso de virdio pesa aproximadamente 200gr. 
; La funcion lee un dato y compara con el valor minimo de un vaso, 
; cuando detecta este valor se fija que en la siguiente lectura
; el valor sea el mismo. Guarda ese valor en VASO_H VASO_L y setea la tara. 
;-------------------------------------------------------------------------

detectar_vaso: 
	push  r16

	ldi   r16, VASO_MINIMO				; peso aproximado de un vaso de vidrio
	ldi   r17, MARGEN_ERROR

detectar_vaso_lectura:
	rcall lectura_peso					; lee un dato y lo escala
	rcall set_scale						
	rcall detectar_cancelacion
	
	tst   DATO_M						
	brne  detectar_vaso_verificacion					
	cp    DATO_L, r16					; compara el peso leido con el peso estandar de un vaso			
	brlo  detectar_vaso_lectura			; si no detecta un cambio vuelve a leer un peso
	
detectar_vaso_verificacion:				; la balanza envia 10 muestras por segundo por lo que la siguiente muestra sera a los 10 ms de la anterior
	mov   VASO_L, DATO_L
	mov   VASO_M, DATO_M
	mov   VASO_H, DATO_H

	rcall lectura_peso					; lee un dato y lo escala
	rcall set_scale						
	rcall detectar_cancelacion
	
	sub   DATO_L, VASO_L				; compara el siguiente valor leido con el anterior			
	sbc   DATO_M, VASO_M
	sbc   DATO_H, VASO_H
	
	brsh  detectar_vaso_next
	rcall com_2							; se toma el modulo de la diferencia de dos valores consecutivos

detectar_vaso_next:
	tst   DATO_H
	brne  detectar_vaso_lectura
	tst   DATO_M
	brne  detectar_vaso_lectura
	cp    DATO_L, r17
	brsh  detectar_vaso_lectura
	
	ldi   zh, HIGH(DIR_MSG_AGUARDE<<1)	; Mensaje hasta que se setea la nueva tara
	ldi   zl, LOW(DIR_MSG_AGUARDE<<1)
	rcall send_msg

	rcall set_tara						; setea la tara ahora con el vaso puesto
	
	pop   r16
	ret
	
;-------------------------------------------------------------------------
; CONFIGURAR_MEDIDA:
; Se espera 3 segundos a que el usuario golpee 2 veces para cambiar la medida
;-------------------------------------------------------------------------
configurar_medida:
	push r16
	push r17
	push r18
	push zl
	push zh

	ldi  r17, 0xFF

configurar_medida_init:
	ldi  zh, HIGH(DIR_MSG_PINTA<<1)
	ldi  zl, LOW(DIR_MSG_PINTA<<1)		; Se inicializa en la medida pinta
	

configurar_medida_loop:
	rcall send_msg						; envia el mensaje correspondiente a la medida cargada

	lpm  MEDIDA_L, Z+					; se guarda la medida seleccionada
	lpm  MEDIDA_H, Z+ 
	
	cp   MEDIDA_L, r17					; si el siguiente valor es 0xFF, ya se recorrieron las 3 medidas
	breq configurar_medida_init
		
	rcall delay_4s						; inicializa el delay de 4 seg
	
	rcall detectar_perturbacion			; se queda esperando una perturbación, si en 4 segundos no detecto nada ya se selecciono una medida	
	brts  configurar_medida_fin			; si esta el bit T=1 significa que pasaron 4 segundos dentro de la funcion detectar_perturbacion

	ldi   r16, (0<<TOIE0)				; se desactiva la interrupcion por overflow
	sts   TIMSK0, r16
	
	rjmp  configurar_medida_loop
 
configurar_medida_fin:					; si pasaron 4 seg, de la subrutina de interrupcion se vuelve aqui	
	ldi   r16, (0<<CS02)|(0<<CS01)|(0<<CS00)
	out   TCCR0B, r16					; config: se apaga el timer

	ldi  r16, (0<<TOIE0)				; se desactiva la interrupcion por overflow
	sts  TIMSK0, r16
	
	clt									; se pone en cero el flag T						

	pop   zh
	pop   zl
	pop   r18
	pop   r17
	pop   r16
	ret	
