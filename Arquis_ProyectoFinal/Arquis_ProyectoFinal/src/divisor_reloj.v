// Divisor de reloj
// Divide la frecuencia de entrada entre 2^N.
// Con N = 2: 50 MHz / 4 = 12.5 MHz para el procesador.
module divisor_reloj #(
	parameter N = 2)
	(
	input  clk_in, rst,
	output clk_out
	);

	reg [N-1:0] contador;

	always @(posedge clk_in or negedge rst) begin
		if (!rst)
			contador <= {N{1'b0}};
		else
			contador <= contador + 1'b1;
	end

	assign clk_out = contador[N-1];

endmodule
