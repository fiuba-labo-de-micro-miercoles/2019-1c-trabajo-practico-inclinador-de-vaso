;====================================================
;MACROS
;====================================================	
; PANTALLA LCD					
.equ  LCD_DPRT = PORTD
.equ  LCD_DDDR = DDRD
.equ  LCD_DPIN = PIND						; Para los datos del LCD se usan los pines D7:D4

.equ  LCD_CPRT = PORTB  
.equ  LCD_CDDR = DDRB
.equ  LCD_CPIN = PINB						; Para los comandos del LCD se utilizan los pines PB1:PB0

.equ  LCD_RS = 4
.equ  LCD_RW = 3
.equ  LCD_E  = 2							; A que pin del PORTB pertencen

.equ  CLEAR_DISPLAY                 = 0x01
.equ  RETURN_HOME                   = 0x02
.equ  DECREMENT_CURSOR              = 0x04
.equ  INCREMENT_CURSOR              = 0x06
.equ  SHIFT_DISPLAY_RIGHT           = 0x05
.equ  SHIFT_DISPLAY_LEFT            = 0x07
.equ  DISP_OFF_CURS_OFF             = 0x08  ; Display apagado, cursor apagado
.equ  DISP_OFF_CURS_ON              = 0x0A  ; Display apagado, cursor prendido
.equ  DISP_ON_CURS_OFF              = 0x0C  ; Display prendido, cursor apagado
.equ  DISP_ON_CURS_BLINK            = 0x0E  ; Display prendido, cursor titilando
.equ  DISP_ON_CURS_NO_BLINK         = 0x0F  ; Display prendido, cursor sin titilar
.equ  SHIFT_CURSOR_LEFT             = 0x10	; Shiftea la posicion del cursor a la izquierda
.equ  SHIFT_CURSOR_RIGHT            = 0x14	; Shiftea la posicion del cursor a la derecha
.equ  SHIFT_ENTIRE_DISPLAY_LEFT     = 0x18	; Shiftea todo el display a la izquierda
.equ  SHIFT_ENTIRE_DISPLAY_RIGHT    = 0x1C	; Shiftea todo el display a la derecha
.equ  CURSOR_LINE_1                 = 0x80	; Fuerza el cursor al ppio de la 1raa linea
.equ  CURSOR_LINE_2                 = 0xC0	; Fuerza el cursor al ppio de la 2da linea
.equ  DATA_4BIT                     = 0x28	; Dos lineas, D4-D7
.equ  DATA_8BIT                     = 0x38	; Dos lineas, D0-D7
.equ  END_OF_MESSAGE				= 0xF0