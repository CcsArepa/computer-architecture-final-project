// Generador de inmediatos
// Arma el inmediato de 32 bits (con extension de signo) segun el formato
// de la instruccion RISC-V: I, S, B, U y J.
module generador_inmediatos (
	input      [31:0] instr,
	output reg [31:0] imm
	);

	// Opcodes
	localparam OP_I    = 7'b0010011, // Tipo Inmediato (addi, andi, ...)
	           OP_LOAD = 7'b0000011, // lw
	           OP_JALR = 7'b1100111, // jalr
	           OP_S    = 7'b0100011, // sw
	           OP_B    = 7'b1100011, // beq, bne, blt
	           OP_U    = 7'b0110111, // lui
	           OP_J    = 7'b1101111; // jal

	always @(*) begin
		case (instr[6:0])
			// Tipo I: imm[11:0] = instr[31:20]
			OP_I, OP_LOAD, OP_JALR: imm = {{20{instr[31]}}, instr[31:20]};

			// Tipo S: imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
			OP_S:    imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

			// Tipo B: imm[12|10:5|4:1|11], el bit 0 siempre es 0
			OP_B:    imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

			// Tipo U: se entregan los 20 bits altos sin recorrer,
			// la ALU (ALU_U_LUI) los recorre 12 lugares a la izquierda
			OP_U:    imm = {12'b0, instr[31:12]};

			// Tipo J: imm[20|10:1|11|19:12], el bit 0 siempre es 0
			OP_J:    imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

			default: imm = 32'b0;
		endcase
	end

endmodule
