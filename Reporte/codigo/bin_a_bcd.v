// Convertidor de binario (0 a 99) a BCD
// Algoritmo "double dabble" (desplazar y sumar 3).
module bin_a_bcd (
	input 	   [6:0] bin,
	output reg [3:0] decenas,
	output reg [3:0] unidades
	);

	reg [14:0] aux;  // [14:11] decenas, [10:7] unidades, [6:0] binario
	integer i;

	always @(*) begin
		aux = {8'b0, bin};
		for (i=0; i<7; i=i+1) begin
			// Si un digito BCD es mayor o igual a 5 se le suma 3
			if (aux[10:7] >= 4'd5)
				aux[10:7] = aux[10:7] + 4'd3;
			if (aux[14:11] >= 4'd5)
				aux[14:11] = aux[14:11] + 4'd3;
			// Se recorre todo un lugar a la izquierda
			aux = aux << 1;
		end
		decenas  = aux[14:11];
		unidades = aux[10:7];
	end

endmodule
