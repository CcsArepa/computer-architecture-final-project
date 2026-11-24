// Banco de registros del procesador RISC-V
// 32 registros de 32 bits (x0 ... x31). El registro x0 siempre vale 0.
// Lectura combinacional (2 puertos) y escritura sincrona (1 puerto).
module banco_registros #(
	parameter nbits = 32)
	(
	input 			   clk, rst,
	input 			   we,          // we=1 : se escribe wd en el registro rd
	input  [4:0] 	   rs1, rs2, rd,
	input  [nbits-1:0] wd,
	output [nbits-1:0] rd1, rd2);

	reg [nbits-1:0] regs [0:31];

	integer i;    // variable tipo entero para contar "i"

	// Escritura (sincrona, reset activo en bajo como en clase)
	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			for (i=0; i<32; i=i+1)
				regs[i] <= {nbits{1'b0}};
		end else if (we && (rd != 5'd0)) begin // x0 nunca se escribe
			regs[rd] <= wd;
		end
	end

	// Lectura (combinacional)
	assign rd1 = (rs1 == 5'd0) ? {nbits{1'b0}} : regs[rs1];
	assign rd2 = (rs2 == 5'd0) ? {nbits{1'b0}} : regs[rs2];

endmodule
