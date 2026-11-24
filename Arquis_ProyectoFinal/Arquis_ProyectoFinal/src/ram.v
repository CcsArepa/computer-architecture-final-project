// RAM de datos de n bits por palabra
// Va a tener 2^m direcciones
// Basada en ram.v de clase.
// MODIFICACION: en el codigo de clase se escribia con (!we), lo cual contradice
// el comentario (we=1 escritura). Aqui se corrigio para que we=1 sea escritura.
// El semaforo la usa para guardar estadisticas (peatones, emergencias, ciclos).
module ram #(
	parameter addr_width = 5, // 2^5 direcciones
	parameter data_width = 32
	)(
	input 					 	 clk,
	input 						 we, // we=0 : modo lectura, we=1 : modo escritura
	input [addr_width-1:0] 		 addr,
	input [data_width-1:0] 		 data_in,
	output reg [data_width-1:0]	 data_out
	);
	// Declaracion de la memoria
	(* ramstyle = "M9K" *) reg [data_width-1:0] ram_data [0:(2**addr_width)-1];

	integer i;
	initial begin
		for (i=0; i<(2**addr_width); i= i+1)
			ram_data[i] = {data_width{1'b0}};
	end

	// Proceso para escritura/lectura
	always @(posedge clk) begin
		if (we)
			ram_data[addr] <= data_in;
		data_out <= ram_data[addr];
	end
endmodule
