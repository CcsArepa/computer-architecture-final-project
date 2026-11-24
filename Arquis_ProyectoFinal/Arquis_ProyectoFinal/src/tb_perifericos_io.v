`timescale 1ns / 1ps

module tb_perifericos_io;

	reg 		clk, rst, we;
	reg  [2:0] 	reg_sel;
	reg  [31:0] data_in;
	wire [31:0] data_out;
	reg  [9:0] 	sw;
	reg 		btn_peaton_n, tick;
	wire [9:0] 	leds;
	wire [6:0] 	cuenta;
	wire [3:0] 	fase;
	wire 		ped_pendiente, tick_pendiente;

	integer errores;
	integer log;   // archivo de resultados (canal 1 = consola tambien)

	// Unidad bajo prueba
	perifericos_io uut (
		.clk(clk), .rst(rst), .we(we), .reg_sel(reg_sel),
		.data_in(data_in), .data_out(data_out),
		.sw(sw), .btn_peaton_n(btn_peaton_n), .tick(tick),
		.leds(leds), .cuenta(cuenta), .fase(fase),
		.ped_pendiente(ped_pendiente), .tick_pendiente(tick_pendiente));

	always #5 clk = ~clk;

	task escribir(input [2:0] r, input [31:0] valor);
		begin
			@(negedge clk); we = 1'b1; reg_sel = r; data_in = valor;
			@(negedge clk); we = 1'b0;
		end
	endtask

	task leer(input [2:0] r, input [31:0] esperado, input [8*16:1] nombre);
		begin
			@(negedge clk); reg_sel = r;
			@(negedge clk);   // lectura sincrona: un flanco despues
			if (data_out !== esperado) begin
				errores = errores + 1;
				$fdisplay(log, "ERROR: %0s = %h, se esperaba %h", nombre, data_out, esperado);
			end else
				$fdisplay(log, "OK   : %0s = %h", nombre, data_out);
		end
	endtask

	initial begin
		clk = 0; rst = 0; we = 0; reg_sel = 0; data_in = 0;
		sw = 10'b0; btn_peaton_n = 1'b1; tick = 1'b0;
		errores = 0;
		log = $fopen("resultados_tb_perifericos_io.txt") | 1;
		$fdisplay(log, "--- INICIANDO PRUEBAS DE PERIFERICOS ---");
		#20 rst = 1;

		// Escritura de luces, cuenta y fase
		escribir(3'd0, 32'h0C8);
		escribir(3'd1, 32'd10);
		escribir(3'd2, 32'd1);
		leer(3'd0, 32'h0C8, "LEDS");
		leer(3'd1, 32'd10,  "CUENTA");
		leer(3'd2, 32'd1,   "FASE");

		// Switches (pasan por el sincronizador)
		sw = 10'b0000000011;
		repeat (3) @(posedge clk);
		leer(3'd3, 32'h003, "SWITCHES");

		// Boton peatonal: un pulso en bajo deja la solicitud guardada
		@(negedge clk) btn_peaton_n = 1'b0;
		repeat (4) @(negedge clk);
		btn_peaton_n = 1'b1;
		repeat (3) @(negedge clk);
		leer(3'd4, 32'd1, "PEATON");
		escribir(3'd4, 32'd0);           // el programa la borra
		leer(3'd4, 32'd0, "PEATON borrado");

		// Tick de 1 segundo
		@(negedge clk) tick = 1'b1;
		@(negedge clk) tick = 1'b0;
		leer(3'd5, 32'd1, "TICK");
		escribir(3'd5, 32'd0);
		leer(3'd5, 32'd0, "TICK borrado");

		if (errores == 0) $fdisplay(log, "\n--- PERIFERICOS: TODAS LAS PRUEBAS PASARON ---");
		else              $fdisplay(log, "\n--- PERIFERICOS: %0d ERRORES ---", errores);
		$finish;
	end

endmodule
