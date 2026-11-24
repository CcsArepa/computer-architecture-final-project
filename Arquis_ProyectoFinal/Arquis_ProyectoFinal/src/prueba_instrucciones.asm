# =====================================================================
# Programa de prueba de instrucciones (lo usa tb_procesador_riscv)
# Cada instruccion deja su resultado en un registro distinto para
# que el testbench lo compare contra el valor esperado.
# =====================================================================
	addi x1, x0, 15         # x1  = 15
	addi x2, x0, 10         # x2  = 10
	add  x3, x1, x2         # x3  = 25
	sub  x4, x1, x2         # x4  = 5
	and  x5, x1, x2         # x5  = 10
	or   x6, x1, x2         # x6  = 15
	xor  x7, x1, x2         # x7  = 5
	slt  x8, x2, x1         # x8  = 1
	mul  x9, x1, x2         # x9  = 150
	addi x10, x0, -3        # x10 = -3
	slti x11, x10, 0        # x11 = 1
	slli x12, x1, 4         # x12 = 240
	srai x13, x10, 1        # x13 = -2
	srli x14, x12, 2        # x14 = 60
	andi x15, x1, 6         # x15 = 6
	ori  x16, x2, 5         # x16 = 15
	xori x17, x1, 255       # x17 = 240
	lui  x18, 0x12345       # x18 = 0x12345000
	sw   x3, 8(x0)          # RAM[2] = 25
	lw   x19, 8(x0)         # x19 = 25
	beq  x3, x19, SALTO1    # se toma
	addi x20, x0, 99        # (no se ejecuta)
SALTO1:
	addi x20, x0, 1         # x20 = 1
	bne  x1, x1, SALTO2     # no se toma
	addi x21, x0, 7         # x21 = 7
SALTO2:
	blt  x10, x0, SALTO3    # -3 < 0, se toma
	addi x21, x0, 66        # (no se ejecuta)
SALTO3:
	jal  x1, SUBRUTINA      # llamada, x1 = direccion de regreso
	addi x22, x22, 1        # x22 = 5 + 1 = 6
	addi x23, x0, 0         # suma de 5 + 4 + 3 + 2 + 1
	addi x24, x0, 5
LAZO:
	add  x23, x23, x24
	addi x24, x24, -1
	bne  x24, x0, LAZO      # x23 = 15, x24 = 0
	sw   x23, 12(x0)        # RAM[3] = 15
	jal  x0, FIN
SUBRUTINA:
	addi x22, x0, 5         # x22 = 5
	jalr x0, 0(x1)          # regresa
FIN:
	jal  x0, FIN            # se queda aqui
