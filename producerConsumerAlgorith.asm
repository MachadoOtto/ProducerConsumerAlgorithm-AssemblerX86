; Laboratorio de Arquitectura de Computadoras - 2021
; Jorge Miguel Machado Ottonelli - C.I: 4.876.616-9

; Definicion de constantes:
; NO MODIFICAR:
INT_CONSUME_INDEX equ 8*4 ; Interrupt TIMER
UNDERFLOW equ 0x0 ; Comando para indicar UNDERFLOW del BUFFER
HAB equ 0x1 ; Comando HAB (termina la carga de datos)
CON equ 0x2 ; Comando CON (carga una pareja productor-consumidor)
SEG_INI equ 500 ; Comienzo de segmentos
;MODIFICAR:
PUERTO_ESTADO equ 128 ; Puerto ESTADO
MAX_BUFFER equ 8 ; Tamaño maximo del BUFFER

; Direcciones del Struct PRODUCTOR_CONSUMIDOR en el segmento:
PP equ 0 ; Puerto Productor
PP_CONTROL equ 2 ; Puerto Control
LAST_CONTROL equ 4 ; Ultima lectura de PP_CONTROL
PC equ 5 ; Puerto Consumidor
TICS equ 7 ; Tics de Consumo (Consumidor)
TIMER equ 9 ; Tics actuales del par
TAM_BUFFER equ 11 ; Cantidad de elementos en el BUFFER
FIRST_ELEM equ 13 ; Direccion del primer elemento del BUFFER
LAST_ELEM equ 15 ; Direccion del ultimo elemento del BUFFER
BUFFER equ 17 ; Inicio del BUFFER

; struct PRODUCTOR_CONSUMIDOR {
;	word ptr puerto_productor - 2bytes
;	word ptr puerto_control - 2bytes
;	byte ptr last_control - 1byte
;	word ptr puerto_consumidor - 2bytes
;	word ptr tics - 2bytes
;	word ptr timer - 2bytes
;	word ptr tam_buffer - 2bytes
;	word ptr first_elem - 2bytes
;	word ptr last_elem - 2bytes
;	char[MAX_BUFFER] *buffer - MAX_BUFFER.bytes
; }

.data ; Segmento de datos
cantidad_pares dw 0 ; Cantidad de pares PRODUCTOR_CONSUMIDOR en el sistema 

.code  ; Segmento de código
MAIN proc
	cli
	xor AX, AX
	mov DS, AX
	mov ES, AX
	; Carga de datos PUERTO_ESTADO:
	call CARGA_DE_DATOS
	; Instalacion de interrupciones:
	mov ES:[INT_CONSUME_INDEX], offset CONSUME
	mov ES:[INT_CONSUME_INDEX + 2], segment CONSUME	
	sti
	; Comienzo del problema de sincronizacion (Productor-Consumidor):
	mov AX, segment cantidad_pares
	mov DS, AX
	mov BX, offset cantidad_pares
	mov AX, DS:[BX]
	mov BX, AX
loop: ; while(true)  ; Peor caso: 33*cantidad_pares instrucciones en total.
	xor AX, AX ; Contiene el segmento del par i
	xor CX, CX ; Contador de iteraciones i
forallPares: ; forall(P : Pares) do
	add AX, SEG_INI ; Segmento += SEG_INI
	inc CX ; i++
	cmp CX, BX
	jg endForallPares
	mov DS, AX
	push AX ; Guardo el segmento
	mov DX, DS:[PP_CONTROL] ; Obtengo el Puerto de Control
	in AX, DX
	and AX, 0x1 ; Obtengo el bit menos significativo de AX
	cmp AL, DS:[LAST_CONTROL] ; if (PP_CONTROL != LAST_CONTROL)
	jz endIfLastNEqual
	mov byte ptr DS:[LAST_CONTROL], AL
	cmp AX, 1 ; if (PP_CONTROL == 1) do
	jnz endIfControl1
	cmp word ptr DS:[TAM_BUFFER], MAX_BUFFER ; if (TAM_BUFFER < MAX_BUFFER) do
	jge endIfMenorTam
	inc word ptr DS:[TAM_BUFFER] ; TAM_BUFFER++
	mov AX, BUFFER
	add AX, MAX_BUFFER
	dec AX
	cmp word ptr DS:[LAST_ELEM], AX ; if (LAST_BUFFER == MAX_BUFFER) do
	jne elseLastMax
	mov word ptr DS:[LAST_ELEM], BUFFER ; LAST_ELEM = BUFFER
	jmp endIfElseLastMax
elseLastMax: ; else (LAST_BUFFER < MAX_BUFFER) do
	inc word ptr DS:[LAST_ELEM] ; LAST_ELEM++
endIfElseLastMax: ; endIfElse
	; Guardar in(PP) al final del BUFFER:
	mov DX, DS:[PP] ; Obtengo el Puerto Productor
	in AX, DX ; Obtengo el dato enviado por el Productor
	push BX ; Guardo cantidad de pares
	mov BX, DS:[LAST_ELEM]
	mov byte ptr DS:[BX], AL ; Almaceno el dato al final del BUFFER
	pop BX ; Recupero cantidad de pares
	jmp endIfLastNEqual
endIfMenorTam: ; endIf (BUFFER OVERFLOW)
	mov AX, DS:[PP]
	out PUERTO_ESTADO, AX ; Retorno el productor con OVERFLOW por PUERTO_ESTADO
endIfControl1: ; endIf (PP_CONTROL == 0)
endIfLastNEqual: ; endIf (PP_CONTROL == LAST_CONTROL)
	pop AX ; Recupero el segmento	
	jmp forallPares
endForallPares: ; endForall
	jmp loop
	ret
MAIN endp

; OPERACION CARGA_DE_DATOS
CARGA_DE_DATOS proc
	push AX
	push CX
	push DS
	xor AX, AX
	xor CX, CX ; Contador de pares Productor-Consumidor
whileNotHAB: ; while(AX != HAB) do
	add AX, SEG_INI
	inc CX ; i++
	mov DS,AX
	push AX ; Guardamos el segmento del par
	; Comprobamos el comando del PUERTO_ESTADO
	in AX, PUERTO_ESTADO
	cmp AX, HAB
	jz endWhileNotHAB
	;cmp AX, CON
	;jz whileNotHAB
	in AX, PUERTO_ESTADO ; Cargamos PP Puerto Productor
	mov DS:[PP], AX
	in AX, PUERTO_ESTADO ; Cargamos PP_CONTROL
	mov DS:[PP_CONTROL], AX
	mov byte ptr DS:[LAST_CONTROL], 0 ; LAST_CONTROL = 0
	in AX, PUERTO_ESTADO ; Cargamos PC Puerto Consumidor
	mov DS:[PC], AX
	in AX, PUERTO_ESTADO ; Cargamos TICS del Consumidor
	mov DS:[TICS], AX
	mov word ptr DS:[TIMER], 0 ; TIMER = 0
	mov word ptr DS:[TAM_BUFFER], 0 ; TAM_BUFFER = 0
	mov word ptr DS:[FIRST_ELEM], BUFFER ; FIRST_ELEM = &BUFFER
	mov word ptr DS:[LAST_ELEM], BUFFER ; LAST_ELEM = &BUFFER
	dec word ptr DS:[LAST_ELEM]
	pop AX ; Recuperamos el segmento del par
	jmp whileNotHAB
endWhileNotHAB: ; endWhile
	pop AX
	; Actualizar cantidad_pares:
	dec CX ; i-- para tener la cantidad total de pares
	push BX
	mov AX, segment cantidad_pares
	mov DS, AX
	mov BX, offset cantidad_pares
	mov DS:[BX], CX
	pop BX
	pop DS
	pop CX
	pop AX
	ret
CARGA_DE_DATOS endp

; INTERRUPCION 'CONSUME' (utiliza el timer)
; Peor caso: 18 + 33*cantidad_pares instrucciones en total.
CONSUME proc far
	push AX
	push BX
	push CX
	push DX
	push DS
	; Obtengo cantidad de pares:
	mov AX, segment cantidad_pares
	mov DS, AX
	mov BX, offset cantidad_pares
	mov AX, DS:[BX]
	mov BX, AX ; BX = cantidad_pares
	; Comienzan a "consumir":
	xor AX, AX ; Segmento par i
	xor CX, CX ; Contador de iteraciones i
forallConsumidores: ; forall (PC : Consumidores)
	add AX, SEG_INI
	inc CX ; i++
	cmp CX, BX ; BX tiene la cantidad de pares guardada.
	jg endForallConsumidores ; if (CX <= cant_pares)
	mov DS, AX
	inc word ptr DS:[TIMER] ; PC[TIMER]++
	push AX ; Guardo el segmento
	mov AX, DS:[TIMER]
	cmp AX, DS:[TICS] ; if (PC[TIMER] == PC[TICS]) do
	pop AX ; Recupero el segmento
	jne endIfNotConsume
	; El consumidor PC "consume" el primer elemento en el BUFFER:
	mov word ptr DS:[TIMER], 0 ; reset PC[TIMER]
	mov DX, DS:[PC]
	cmp word ptr DS:[TAM_BUFFER], 0 ; if (TAM_BUFFER > 0) do
	jz elseHasNoElem
	push AX ; Guardo el segmento
	push BX ; Guardo cantidad de pares
	mov BX, DS:[FIRST_ELEM]
	mov AX, DS:[BX]
	out DX, AL
	dec word ptr DS:[TAM_BUFFER]
	pop BX ; Recupero cantidad de pares
	pop AX ; Recupero el segmento
	; Incremento posicion del primer elemento en el BUFFER
	push AX ; Guardo el segmento
	mov AX, BUFFER
	add AX, MAX_BUFFER
	dec AX
	cmp word ptr DS:[FIRST_ELEM], AX ; if (FIRST_ELEM == MAX_BUFFER) do
	pop AX ; Recupero el segmento
	jne elseFirstNotMax
	mov word ptr DS:[FIRST_ELEM], BUFFER ; FIRST_ELEM = &BUFFER
	jmp endIfNotConsume
elseFirstNotMax: ; else (FIRST_ELEM < MAX_BUFFER) do
	inc word ptr DS:[FIRST_ELEM] ; FIRST_ELEM++
	jmp endIfNotConsume
elseHasNoElem: ; else (UNDERFLOW)
	push AX ; Guardo el segmento
	mov AX, UNDERFLOW
	out DX, AX ; Devolvemos por el Puerto Consumidor 0x0 (UNDERFLOW)
	pop AX ; Recupero el segmento
endIfNotConsume:
	jmp forallConsumidores
endForallConsumidores:
	pop DS
	pop DX
	pop CX
	pop BX
	pop AX
	iret
CONSUME endp

.ports ; Definición de puertos


.interrupts ; Manejadores de interrupciones