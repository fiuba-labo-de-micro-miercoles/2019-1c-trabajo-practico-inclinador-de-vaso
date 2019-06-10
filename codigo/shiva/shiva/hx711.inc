;-------------------------------------------------------------------------
; CONSTANTES y MACROS
;-------------------------------------------------------------------------
.equ  SCK  = PC0					; pin donde se conecta SCK
.equ  DOUT = PC1					; pin donde se conecta DOUT
.equ  MULTIPLICADOR = 77			; Factor de multiplicacion de la escala del peso del programa en C ~ 77/2^14

;-------------------------------------------------------------------------
; VARIABLES EN REGISTROS
;-------------------------------------------------------------------------
.def  DATO_H = r4
.def  DATO_M = r3
.def  DATO_L = r2

.def TARA_H	= r7
.def TARA_M	= r6
.def TARA_L = r5

.def  CONT_8 = r17