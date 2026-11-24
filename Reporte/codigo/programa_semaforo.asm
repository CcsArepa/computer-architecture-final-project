# =====================================================================
# Programa del semaforo inteligente (RISC-V)
# ---------------------------------------------------------------------
# Registros:
#   s0 = 0x400, base de los perifericos
#   s1 = segundos restantes de la fase
#   s2 = 1 si el boton peatonal puede acortar la fase
#   t0, t1, t2 = temporales     ra = direccion de retorno
# Perifericos (desplazamiento sobre s0):
#   0(s0) LEDS   4(s0) CUENTA   8(s0) FASE
#   12(s0) SWITCHES (bit0 = autos, bit1 = emergencia)
#   16(s0) PEATON   20(s0) TICK
# RAM de datos (estadisticas):
#   0(x0) peatones atendidos  4(x0) emergencias  8(x0) ciclos de la calle
# Luces (LEDR):  9 AV_R  8 AV_A  7 AV_V | 6 CA_R  5 CA_A  4 CA_V | 3 PE_R  2 PE_V
# =====================================================================

INICIO:
	addi s0, x0, 1024       # s0 = 0x400 (perifericos)
	sw   x0, 0(x0)          # peatones = 0
	sw   x0, 4(x0)          # emergencias = 0
	sw   x0, 8(x0)          # ciclos de la calle = 0

# ---------- Fase 1: avenida en verde (minimo 10 s) ----------
AV_VERDE:
	addi t0, x0, 200        # 0x0C8: AV verde, CALLE rojo, PEATON rojo
	sw   t0, 0(s0)
	addi t0, x0, 1
	sw   t0, 8(s0)          # fase 1
	addi s1, x0, 10         # 10 segundos
	addi s2, x0, 1          # el peaton puede acortar esta fase
	jal  ra, CUENTA

# La avenida se queda en verde hasta que llegue un auto o un peaton
AV_ESPERA:
	lw   t0, 12(s0)         # lee switches
	andi t1, t0, 2
	bne  t1, x0, EMERGENCIA
	lw   t1, 16(s0)         # hay peaton?
	bne  t1, x0, AV_AMARILLO
	andi t1, t0, 1          # hay auto en la calle?
	bne  t1, x0, AV_AMARILLO
	jal  x0, AV_ESPERA

# ---------- Fase 2: avenida en amarillo (3 s) ----------
AV_AMARILLO:
	addi t0, x0, 328        # 0x148: AV amarillo, CALLE rojo, PEATON rojo
	sw   t0, 0(s0)
	addi t0, x0, 2
	sw   t0, 8(s0)          # fase 2
	addi s1, x0, 3
	addi s2, x0, 0
	jal  ra, CUENTA
	lw   t1, 16(s0)         # si hay peaton, primero pasa el peaton
	bne  t1, x0, PEATONES

# ---------- Fase 3: calle en verde (8 s) ----------
CALLE_VERDE:
	lw   t0, 8(x0)          # ciclos de la calle + 1 (en RAM)
	addi t0, t0, 1
	sw   t0, 8(x0)
	addi t0, x0, 536        # 0x218: AV rojo, CALLE verde, PEATON rojo
	sw   t0, 0(s0)
	addi t0, x0, 3
	sw   t0, 8(s0)          # fase 3
	addi s1, x0, 8
	addi s2, x0, 0
	jal  ra, CUENTA

# ---------- Fase 4: calle en amarillo (3 s) ----------
CALLE_AMARILLO:
	addi t0, x0, 552        # 0x228: AV rojo, CALLE amarillo, PEATON rojo
	sw   t0, 0(s0)
	addi t0, x0, 4
	sw   t0, 8(s0)          # fase 4
	addi s1, x0, 3
	addi s2, x0, 0
	jal  ra, CUENTA
	lw   t1, 16(s0)
	bne  t1, x0, PEATONES
	jal  x0, AV_VERDE

# ---------- Fase 5: cruce peatonal (7 s) ----------
PEATONES:
	sw   x0, 16(s0)         # se atiende (borra) la solicitud
	lw   t0, 0(x0)          # peatones + 1 (en RAM)
	addi t0, t0, 1
	sw   t0, 0(x0)
	addi t0, x0, 580        # 0x244: AV rojo, CALLE rojo, PEATON verde
	sw   t0, 0(s0)
	addi t0, x0, 5
	sw   t0, 8(s0)          # fase 5
	addi s1, x0, 7
	addi s2, x0, 0
	jal  ra, CUENTA
	jal  x0, AV_VERDE

# ---------- Emergencia: todo en rojo mientras SW[1] = 1 ----------
EMERGENCIA:
	lw   t0, 4(x0)          # emergencias + 1 (en RAM)
	addi t0, t0, 1
	sw   t0, 4(x0)
	addi t0, x0, 584        # 0x248: todos en rojo
	sw   t0, 0(s0)
	addi t0, x0, 14
	sw   t0, 8(s0)          # fase E
	sw   x0, 4(s0)          # cuenta 00
EMERG_ESPERA:
	lw   t0, 12(s0)
	andi t1, t0, 2
	bne  t1, x0, EMERG_ESPERA
	jal  x0, AV_VERDE

# =====================================================================
# Subrutina CUENTA: cuenta regresiva de s1 segundos
#  - muestra s1 en los displays
#  - si se activa la emergencia salta a EMERGENCIA
#  - si s2 = 1 y hay peaton, recorta la cuenta a 3 segundos
# =====================================================================
CUENTA:
	sw   x0, 20(s0)         # descarta un tick viejo
CUENTA_LAZO:
	sw   s1, 4(s0)          # muestra los segundos
	lw   t0, 12(s0)
	andi t1, t0, 2
	bne  t1, x0, EMERGENCIA
	beq  s2, x0, CUENTA_TICK
	lw   t1, 16(s0)
	beq  t1, x0, CUENTA_TICK
	addi t2, x0, 3
	blt  t2, s1, CUENTA_CORTA   # si 3 < s1 se recorta
	jal  x0, CUENTA_TICK
CUENTA_CORTA:
	addi s1, x0, 3
CUENTA_TICK:
	lw   t1, 20(s0)         # ya paso un segundo?
	beq  t1, x0, CUENTA_LAZO
	sw   x0, 20(s0)         # borra el tick
	addi s1, s1, -1
	bne  s1, x0, CUENTA_LAZO
	sw   s1, 4(s0)          # muestra 00
	jalr x0, 0(ra)          # regresa
