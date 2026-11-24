// Procesador RISC-V (RV32I reducido + mul) multiciclo
// Ruta de datos: une los modulos de clase (pipo_register, rom_file, alu_riscv,
// adder_nbits, mux_4a1) con el banco de registros, el generador de inmediatos
// y la unidad de control.
// Bus de datos externo: mem_addr / mem_wdata / mem_we / mem_rdata
// (ahi se conectan la RAM y los perifericos del semaforo).
module procesador_riscv #(
	parameter ROM_ADDR = 7,                       // 2^7 = 128 instrucciones
	parameter ROM_FILE = "programa_semaforo.hex"
	)(
	input 		  clk, rst,
	// Bus de datos
	output [31:0] mem_addr,
	output [31:0] mem_wdata,
	output 		  mem_we,
	input  [31:0] mem_rdata,
	// Senales para depurar en simulacion
	output [31:0] pc_actual,
	output [31:0] instr_actual,
	output [3:0]  estado
	);

	wire [31:0] pc, pc_next, pc_plus4, pc_target;
	wire [31:0] instr, imm, rd1, rd2, alu_b, alu_result, wb_data;
	wire 		pc_write, reg_write, mem_read, mem_write, alu_src;
	wire 		branch, jump, jalr;
	wire [1:0] 	wb_sel;
	wire [6:0] 	alu_mode;
	wire [4:0] 	alu_op;
	wire 		carry, overflow, zero, negativo;

	// Contador de programa (registro PIPO de clase)
	pipo_register #(.nbits(32), .INIT_VALUE(32'h00000000)) PC (
		.clk(clk), .rst(rst), .enable(pc_write), .d(pc_next), .q(pc));

	// Memoria de instrucciones (direccion de palabra = PC / 4)
	rom_file #(.DATA_WIDTH(32), .ADDR_WIDTH(ROM_ADDR), .INIT_FILE(ROM_FILE)) ROM (
		.clk(clk), .addr(pc[ROM_ADDR+1:2]), .data_out(instr));

	// Unidad de control
	unidad_control UC (
		.clk(clk), .rst(rst),
		.opcode(instr[6:0]), .funct3(instr[14:12]), .funct7(instr[31:25]),
		.pc_write(pc_write), .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
		.alu_src(alu_src), .wb_sel(wb_sel), .branch(branch), .jump(jump), .jalr(jalr),
		.alu_mode(alu_mode), .alu_op(alu_op), .estado(estado));

	// Banco de registros
	banco_registros #(.nbits(32)) RF (
		.clk(clk), .rst(rst), .we(reg_write),
		.rs1(instr[19:15]), .rs2(instr[24:20]), .rd(instr[11:7]),
		.wd(wb_data), .rd1(rd1), .rd2(rd2));

	// Generador de inmediatos
	generador_inmediatos IMM (.instr(instr), .imm(imm));

	// ALU de clase. La entrada C no se usa (solo para (A+B)*C)
	assign alu_b = alu_src ? imm : rd2;

	alu_riscv ALU (
		.A(rd1), .B(alu_b), .C(32'd0),
		.opcode(alu_mode), .alu_op(alu_op),
		.Result(alu_result),
		.Carry(carry), .Overflow(overflow), .Zero(zero), .Negativo(negativo));

	// Sumadores del PC (adder_nbits de clase)
	adder_nbits #(.nbits(32)) SUMA_PC4   (.a(pc), .b(32'd4), .out1(pc_plus4));
	adder_nbits #(.nbits(32)) SUMA_SALTO (.a(pc), .b(imm),   .out1(pc_target));

	// Siguiente PC
	wire tomar_salto = jump | (branch & alu_result[0]);
	assign pc_next = jalr        ? alu_result :
	                 tomar_salto ? pc_target  : pc_plus4;

	// Multiplexor de escritura al banco de registros (mux_4a1 de clase)
	mux_4a1 #(.n(32)) MUX_WB (
		.I3(32'd0), .I2(pc_plus4), .I1(mem_rdata), .I0(alu_result),
		.Sel(wb_sel), .S(wb_data));

	// Bus de datos
	assign mem_addr  = alu_result;
	assign mem_wdata = rd2;
	assign mem_we    = mem_write;

	assign pc_actual    = pc;
	assign instr_actual = instr;

endmodule
