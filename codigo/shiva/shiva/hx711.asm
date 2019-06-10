

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

;-------------------------------------------------------------------------
; CARGAR_BYTE: 
; Carga 8 bits del amplificador uno por uno y los guarda en r16.
;-------------------------------------------------------------------------

cargar_byte:
	clr   r16
	ldi   CONT_8, 8
cargar_bit:
	sbi   PORTC, SCK				; se genera un flanco ascendente en la señal SCK para cargar un bit
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


; ----------------------------------------------------------------------------
; SEND_DATA: 
; envia los registros r4:r2 por la USART. Funcion de prueba
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