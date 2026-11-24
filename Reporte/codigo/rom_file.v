// ROM de programa (memoria de instrucciones)
// Basada en rom_file.v de clase. Se agrego el parametro INIT_FILE para
// poder escoger el archivo .hex con el programa que va a ejecutar el procesador.
module rom_file #(
	parameter DATA_WIDTH = 32,
	parameter ADDR_WIDTH = 7,                       // 2^7 = 128 instrucciones
	parameter INIT_FILE  = "programa_semaforo.hex"
	)(
	input 				   		clk,
	input [ADDR_WIDTH-1:0] 		addr,
	output reg [DATA_WIDTH-1:0] data_out);

	// Declaracion de la memoria
	(* ramstyle = "M9K" *) reg [DATA_WIDTH-1:0] rom [0:2**ADDR_WIDTH-1];

	initial
		begin
			$readmemh(INIT_FILE, rom);
		end

	// Lectura sincrona: el dato sale un flanco despues de poner la direccion
	always @(posedge clk)
		begin
			data_out <= rom[addr];
		end
endmodule
