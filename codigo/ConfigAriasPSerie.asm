;-------------------------------------------------------------------------
; AVR - Configuraci�n y transmisi�n por puerto serie
;-------------------------------------------------------------------------
;-------------------------------------------------------------------------
; MCU: ATmega8 con oscilador interno a 8 MHz
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
; INCLUSIONES
;-------------------------------------------------------------------------
.include "m8def.inc"

;-------------------------------------------------------------------------
; CONSTANTES y MACROS
;-------------------------------------------------------------------------
.include "avr_macros.inc"
.listmac				; permite que se expandan las macros en el listado

.equ	 BUF_SIZE	= 64	; tama�o en bytes del buffer de transmisi�n

;-------------------------------------------------------------------------
; variables en SRAM
;-------------------------------------------------------------------------
		.dseg 
TX_BUF:	.byte	BUF_SIZE	; buffer de transmisi�n

;-------------------------------------------------------------------------
; variables en registros
;-------------------------------------------------------------------------
.def	ptr_tx_L = r8		; puntero al buffer de datos a transmitir
.def	ptr_tx_H = r9
.def	bytes_a_tx = r10 	; nro. de bytes a transmitir desde el buffer

.def	t0	= r16
.def	t1	= r17

;-------------------------------------------------------------------------
; codigo
;-------------------------------------------------------------------------
		.cseg
		rjmp	RESET			; interrupci�n del reset

		.org	URXCaddr		; USART, Rx Complete
		rjmp	ISR_RX_USART_COMPLETA
	
		.org	UDREaddr		; USART Data Register Empty
		rjmp	ISR_REG_USART_VACIO

		.org 	INT_VECTORS_SIZE

RESET:	ldi 	r16,LOW(RAMEND)
		out 	spl,r16
		ldi 	r16,HIGH(RAMEND)
		out 	sph,r16		; inicializaci�n del puntero a la pila

		rcall	USART_init	; Configuraci�n del puerto serie a 76k8 bps

		sei					; habilitaci�n global de todas las interrupciones

		rcall	TEST_TX

X_SIEMPRE:
		rjmp	X_SIEMPRE


;-------------------------------------------------------------------------
;					COMUNICACION SERIE
;-------------------------------------------------------------------------
.equ	BAUD_RATE	= 25	; 12	76.8 kbps e=0.2%	@8MHz y U2X=1
							; 25	38.4 kbps e=0.2%	@8MHz y U2X=1
							; 51	19.2 kbps e=0.2% 	@8MHz y U2X=1
							; 103	9600 bps  e=0.2% 	@8MHz y U2X=1
;-------------------------------------------------------------------------
USART_init:
		push	t0
		push	t1
		pushw	X
	
		outi	UBRRH,high(BAUD_RATE)	; Velocidad de transmisi�n
		outi	UBRRL,low(BAUD_RATE)
		outi	UCSRA,(1<<U2X)			; Modo asinc., doble velocidad

		; Trama: 8 bits de datos, sin paridad y 1 bit de stop, 
		outi 	UCSRC,(1<<URSEL)|(0<<UPM1)|(0<<UPM0)|(0<<USBS)|(1<<UCSZ1)|(1<<UCSZ0)

		; Configura los terminales de TX y RX; y habilita
		; 	�nicamente la int. de recepci�n
		outi	UCSRB,(1<<RXCIE)|(1<<RXEN)|(1<<TXEN)|(0<<UDRIE)

		movi	ptr_tx_L,LOW(TX_BUF)	; inicializa puntero al 
		movi	ptr_tx_H,HIGH(TX_BUF)	; buffer de transmisi�n.
	
		ldiw	X,TX_BUF				; limpia BUF_SIZE posiciones 
		ldi		t1, BUF_SIZE			; del buffer de transmisi�n
		clr		t0
loop_limpia:
		st		X+,t0
		dec		t1
		brne	loop_limpia
					
		clr		bytes_a_tx		; nada pendiente de transmisi�n

		popw	X
		pop		t1
		pop		t0
		ret


;-------------------------------------------------------------------------
; RECEPCION: Interrumpe cada vez que se recibe un byte x RS232.
;
; Recibe:	UDR (byte de dato)
; Devuelve: nada
;-------------------------------------------------------------------------
ISR_RX_USART_COMPLETA:
;
; EL registro UDR tiene un dato y deber�a ser procesado
;
    	reti 

;------------------------------------------------------------------------
; TRANSMISION: interrumpe cada vez que puede transmitir un byte.
; Se transmiten "bytes_a_tx" comenzando desde la posici�n TX_BUF del
; buffer. Si "bytes_a_tx" llega a cero, se deshabilita la interrupci�n.
;
; Recibe: 	bytes_a_tx.
; Devuelve: ptr_tx_H:ptr_tx_L, y bytes_a_tx.
;------------------------------------------------------------------------
ISR_REG_USART_VACIO:		; UDR est� vac�o
		push	t0
		push	t1
		pushi	SREG
		pushw	X


		tst		bytes_a_tx	; hay datos pendientes de transmisi�n?
		breq	FIN_TRANSMISION

		movw	XL,ptr_tx_L	; Recupera puntero al pr�ximo byte a tx.
		ld		t0,X+		; lee byte del buffer y apunta al
		out		UDR,t0		; sgte. dato a transmitir (en la pr�xima int.)

		cpi		XL,LOW(TX_BUF+BUF_SIZE)
		brlo	SALVA_PTR_TX
		cpi		XH,HIGH(TX_BUF+BUF_SIZE)
		brlo	SALVA_PTR_TX
		ldiw	X,TX_BUF	; ptr_tx=ptr_tx+1, (m�dulo BUF_SIZE)

SALVA_PTR_TX:
		movw	ptr_tx_L,XL	; preserva puntero a sgte. dato

		dec		bytes_a_tx	; Descuenta el nro. de bytes a tx. en 1
		brne	SIGUE_TX	; si quedan datos que transmitir
							;	vuelve en la pr�xima int.

FIN_TRANSMISION:			; si no hay nada que enviar,
		cbi		UCSRB,UDRIE	; 	se deshabilita la interrupci�n.

sigue_tx:
		popw	X
		popi	SREG
		pop		t1
		pop		t0
		reti

;-------------------------------------------------------------------------
; TEST_TX: transmite el mensaje almacenado en memoria flash a partir
; de la direcci�n MSJ_TEST_TX que termina con 0x00 (el 0 no se transmite).
; Recibe: nada
; Devuelve: ptr_tx_L|H, bytes_a_tx.  
; Habilita la int. de transmisi�n serie con ISR en ISR_REG_USART_VACIO().
;-------------------------------------------------------------------------
TEST_TX:
		pushw	Z
		pushw	X
		push	t0

		ldiw	Z,(MSJ_TEST_TX*2)
		movw	XL,ptr_tx_L

LOOP_TEST_TX:
		lpm		t0,Z+
		tst		t0
		breq	FIN_TEST_TX

		st		X+,t0
		inc		bytes_a_tx

		cpi		XL,LOW(TX_BUF+BUF_SIZE)
		brlo	LOOP_TEST_TX
		cpi		XH,HIGH(TX_BUF+BUF_SIZE)
		brlo	LOOP_TEST_TX
		ldiw	X,TX_BUF	; ptr_tx++ m�dulo BUF_SIZE

		rjmp	LOOP_TEST_TX
	
FIN_TEST_TX:
		sbi		UCSRB,UDRIE

		pop		t0
		popw	X
		popw	Z
		ret

MSJ_TEST_TX:
.db		"Puerto Serie Version 0.1 ",'\r','\n',0


;-------------------------------------------------------------------------
; fin del c�digo
;-------------------------------------------------------------------------