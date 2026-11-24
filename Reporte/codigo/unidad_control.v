// Unidad de control del procesador RISC-V multiciclo
// Basada en uc_simple.v de clase: misma maquina de estados (FETCH, DECODE,
// EXEC_R, MEM_ADDR, MEM_READ, MEM_WRITE, WRITEBACK) mas dos estados nuevos
// para saltos (EXEC_B y EXEC_J). Tambien genera las senales para la ALU.
module unidad_control (
	input clk, rst,
	input [6:0] opcode,
	input [2:0] funct3,
	input [6:0] funct7,
	output reg 		 pc_write,   // actualiza el PC
	output reg 		 reg_write,  // escribe en el banco de registros
	output reg 		 mem_read,   // lectura de memoria (informativa)
	output reg 		 mem_write,  // escritura en memoria / perifericos
	output reg 		 alu_src,    // 0: B = rs2, 1: B = inmediato
	output reg [1:0] wb_sel,     // 00: ALU, 01: memoria, 10: PC+4
	output reg 		 branch,     // instruccion de salto condicional
	output reg 		 jump,       // jal
	output reg 		 jalr,       // jalr
	output reg [6:0] alu_mode,   // opcode que recibe alu_riscv
	output reg [4:0] alu_op,     // operacion que recibe alu_riscv
	output 	   [3:0] estado      // estado actual (para depurar)
);

	// OpCodes (7 bits)
	localparam OP_R      = 7'b0110011,
	           OP_I      = 7'b0010011,
	           OP_LOAD   = 7'b0000011,
	           OP_STORE  = 7'b0100011,
	           OP_BRANCH = 7'b1100011,
	           OP_LUI    = 7'b0110111,
	           OP_JAL    = 7'b1101111,
	           OP_JALR   = 7'b1100111;

	// Opcodes que entiende la ALU de clase (alu_riscv)
	localparam ALU_MODE_R = 7'b0110011,
	           ALU_MODE_I = 7'b0010011,
	           ALU_MODE_B = 7'b1100011,
	           ALU_MODE_S = 7'b0100011,
	           ALU_MODE_U = 7'b0110111,
	           ALU_MODE_J = 7'b1101111;

	// Codigos de operacion de la ALU (los mismos de alu_riscv)
	localparam ALU_ADD     = 5'b00000,
	           ALU_SUB     = 5'b00001,
	           ALU_AND     = 5'b00010,
	           ALU_OR      = 5'b00011,
	           ALU_XOR     = 5'b00100,
	           ALU_SLL     = 5'b00110,
	           ALU_SRL     = 5'b00111,
	           ALU_SRA     = 5'b01001,
	           ALU_MUL     = 5'b01011,
	           ALU_I_SLTI  = 5'b01100,
	           ALU_I_LW    = 5'b01101,
	           ALU_B_BEQ   = 5'b01111,
	           ALU_B_BNE   = 5'b10000,
	           ALU_B_BLT   = 5'b10001,
	           ALU_S_SW    = 5'b10010,
	           ALU_U_LUI   = 5'b10101,
	           ALU_J_JAL   = 5'b11000,
	           ALU_J_JALR  = 5'b11010;

	// Estados (fases del procesador)
	localparam FETCH      = 4'b0000,
	           DECODE     = 4'b0001,
	           EXEC_R     = 4'b0010,
	           MEM_ADDR   = 4'b0011,
	           MEM_READ   = 4'b0100,
	           MEM_WRITE  = 4'b0101,
	           WRITEBACK  = 4'b0110,
	           EXEC_B     = 4'b0111,
	           EXEC_J     = 4'b1000;

	reg [3:0] current_state, next_state;

	assign estado = current_state;

	// Solo estas instrucciones escriben un resultado en rd durante WRITEBACK
	wire escribe_rd = (opcode == OP_R) || (opcode == OP_I) ||
	                  (opcode == OP_LOAD) || (opcode == OP_LUI);

	// Registro de estado
	always @(posedge clk or negedge rst) begin
		if (!rst)
			current_state <= FETCH;
		else
			current_state <= next_state;
	end

	// Logica de transicion de estados
	always @(*) begin
		case (current_state)

			FETCH:
				next_state = DECODE;

			DECODE: begin
				case (opcode)
					OP_R, OP_I, OP_LUI: next_state = EXEC_R;
					OP_LOAD:            next_state = MEM_ADDR;
					OP_STORE:           next_state = MEM_ADDR;
					OP_BRANCH:          next_state = EXEC_B;
					OP_JAL, OP_JALR:    next_state = EXEC_J;
					default:            next_state = WRITEBACK; // instruccion no valida = NOP
				endcase
			end

			EXEC_R:
				next_state = WRITEBACK;

			MEM_ADDR:
				next_state = (opcode == OP_LOAD) ? MEM_READ : MEM_WRITE;

			MEM_READ:
				next_state = WRITEBACK;

			MEM_WRITE:
				next_state = FETCH;

			WRITEBACK:
				next_state = FETCH;

			EXEC_B:
				next_state = FETCH;

			EXEC_J:
				next_state = FETCH;

			default:
				next_state = FETCH;

		endcase
	end

	// Logica de salidas (depende del estado)
	always @(*) begin
		pc_write  = 1'b0;
		reg_write = 1'b0;
		mem_read  = 1'b0;
		mem_write = 1'b0;

		case (current_state)

			MEM_READ:
				mem_read = 1'b1;

			MEM_WRITE: begin
				mem_write = 1'b1;
				pc_write  = 1'b1;
			end

			WRITEBACK: begin
				reg_write = escribe_rd;
				pc_write  = 1'b1;
			end

			EXEC_B:
				pc_write  = 1'b1;

			EXEC_J: begin
				reg_write = 1'b1;   // rd = PC + 4
				pc_write  = 1'b1;
			end

			default: ;

		endcase
	end

	// Decodificador de la instruccion (depende del opcode, funct3 y funct7)
	always @(*) begin
		alu_src  = 1'b0;
		wb_sel   = 2'b00;
		branch   = 1'b0;
		jump     = 1'b0;
		jalr     = 1'b0;
		alu_mode = ALU_MODE_R;
		alu_op   = ALU_ADD;

		case (opcode)
			OP_R: begin
				alu_mode = ALU_MODE_R;
				case (funct3)
					3'b000:  alu_op = (funct7 == 7'b0000001) ? ALU_MUL :
					                  (funct7[5] ? ALU_SUB : ALU_ADD);
					3'b001:  alu_op = ALU_SLL;
					3'b010:  alu_op = ALU_I_SLTI;  // slt
					3'b100:  alu_op = ALU_XOR;
					3'b101:  alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
					3'b110:  alu_op = ALU_OR;
					3'b111:  alu_op = ALU_AND;
					default: alu_op = ALU_ADD;
				endcase
			end

			OP_I: begin
				alu_mode = ALU_MODE_I;
				alu_src  = 1'b1;
				case (funct3)
					3'b000:  alu_op = ALU_ADD;     // addi
					3'b001:  alu_op = ALU_SLL;     // slli
					3'b010:  alu_op = ALU_I_SLTI;  // slti
					3'b100:  alu_op = ALU_XOR;     // xori
					3'b101:  alu_op = funct7[5] ? ALU_SRA : ALU_SRL; // srai / srli
					3'b110:  alu_op = ALU_OR;      // ori
					3'b111:  alu_op = ALU_AND;     // andi
					default: alu_op = ALU_ADD;
				endcase
			end

			OP_LOAD: begin  // lw: direccion = rs1 + imm
				alu_mode = ALU_MODE_I;
				alu_op   = ALU_I_LW;
				alu_src  = 1'b1;
				wb_sel   = 2'b01;
			end

			OP_STORE: begin // sw: direccion = rs1 + imm
				alu_mode = ALU_MODE_S;
				alu_op   = ALU_S_SW;
				alu_src  = 1'b1;
			end

			OP_BRANCH: begin // la ALU entrega 1 si se cumple la condicion
				alu_mode = ALU_MODE_B;
				branch   = 1'b1;
				case (funct3)
					3'b000:  alu_op = ALU_B_BEQ;
					3'b001:  alu_op = ALU_B_BNE;
					3'b100:  alu_op = ALU_B_BLT;
					default: alu_op = ALU_B_BEQ;
				endcase
			end

			OP_LUI: begin
				alu_mode = ALU_MODE_U;
				alu_op   = ALU_U_LUI;
				alu_src  = 1'b1;
			end

			OP_JAL: begin
				alu_mode = ALU_MODE_J;
				alu_op   = ALU_J_JAL;
				jump     = 1'b1;
				wb_sel   = 2'b10;
			end

			OP_JALR: begin // nuevo PC = (rs1 + imm) & ~1
				alu_mode = ALU_MODE_J;
				alu_op   = ALU_J_JALR;
				alu_src  = 1'b1;
				jalr     = 1'b1;
				wb_sel   = 2'b10;
			end

			default: ;
		endcase
	end

endmodule
