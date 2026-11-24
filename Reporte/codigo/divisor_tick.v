// Generador de tick de 1 segundo
// Cuenta DIV ciclos de reloj y genera un pulso de un ciclo (tick).
// Con el reloj del procesador de 12.5 MHz: DIV = 12_500_000 -> 1 segundo.
// latido cambia de valor en cada tick (LED que parpadea).
module divisor_tick #(
	parameter DIV = 12_500_000)
	(
	input 	   clk, rst,
	output reg tick,
	output reg latido
	);

	reg [31:0] contador;

	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			contador <= 32'd0;
			tick 	 <= 1'b0;
			latido 	 <= 1'b0;
		end else if (contador == DIV-1) begin
			contador <= 32'd0;
			tick 	 <= 1'b1;
			latido 	 <= ~latido;
		end else begin
			contador <= contador + 32'd1;
			tick 	 <= 1'b0;
		end
	end

endmodule
