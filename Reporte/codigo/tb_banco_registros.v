`timescale 1ns / 1ps

module tb_banco_registros;

	// 1. Declaracion de senales
	reg 		clk, rst, we;
	reg  [4:0]  rs1, rs2, rd;
	reg  [31:0] wd;
	wire [31:0] rd1, rd2;

	integer errores;
	integer log;   // archivo de resultados (canal 1 = consola tambien)

	// 2. Instanciacion de la Unidad Bajo Prueba (UUT)
	banco_registros #(.nbits(32)) uut (
		.clk(clk), .rst(rst), .we(we),
		.rs1(rs1), .rs2(rs2), .rd(rd),
		.wd(wd), .rd1(rd1), .rd2(rd2));

	always #5 clk = ~clk;

	// Tarea para escribir un registro
	task escribir(input [4:0] r, input [31:0] valor);
		begin
			@(negedge clk);
			we = 1'b1; rd = r; wd = valor;
			@(negedge clk);
			we = 1'b0;
		end
	endtask

	// Tarea para comparar una lectura
	task revisar(input [4:0] r, input [31:0] esperado);
		begin
			rs1 = r; rs2 = r; #1;
			if (rd1 !== esperado || rd2 !== esperado) begin
				errores = errores + 1;
				$fdisplay(log, "ERROR: x%0d = %h (rd2 = %h), se esperaba %h", r, rd1, rd2, esperado);
			end else
				$fdisplay(log, "OK   : x%0d = %h", r, rd1);
		end
	endtask

	// 3. Bloque de estimulos
	initial begin
		clk = 0; rst = 0; we = 0;
		rs1 = 0; rs2 = 0; rd = 0; wd = 0;
		errores = 0;
		log = $fopen("resultados_tb_banco_registros.txt") | 1;

		$fdisplay(log, "--- INICIANDO PRUEBAS DEL BANCO DE REGISTROS ---");
		#20 rst = 1;

		// Prueba 1: despues del reset todo vale 0
		revisar(5'd1, 32'd0);
		revisar(5'd31, 32'd0);

		// Prueba 2: escritura y lectura
		escribir(5'd1,  32'd15);
		escribir(5'd2,  32'hDEADBEEF);
		escribir(5'd31, 32'hFFFFFFFF);
		revisar(5'd1,  32'd15);
		revisar(5'd2,  32'hDEADBEEF);
		revisar(5'd31, 32'hFFFFFFFF);

		// Prueba 3: x0 no se puede escribir
		escribir(5'd0, 32'h12345678);
		revisar(5'd0, 32'd0);

		// Prueba 4: lectura de dos registros distintos al mismo tiempo
		rs1 = 5'd1; rs2 = 5'd2; #1;
		if (rd1 === 32'd15 && rd2 === 32'hDEADBEEF)
			$fdisplay(log, "OK   : lectura doble rd1 = %0d, rd2 = %h", rd1, rd2);
		else begin
			errores = errores + 1;
			$fdisplay(log, "ERROR: lectura doble");
		end

		// Prueba 5: sin we no se escribe
		@(negedge clk); we = 1'b0; rd = 5'd1; wd = 32'd99;
		@(negedge clk);
		revisar(5'd1, 32'd15);

		// Prueba 6: reset borra todo
		#3 rst = 0; #10 rst = 1;
		revisar(5'd2, 32'd0);

		if (errores == 0) $fdisplay(log, "\n--- BANCO DE REGISTROS: TODAS LAS PRUEBAS PASARON ---");
		else              $fdisplay(log, "\n--- BANCO DE REGISTROS: %0d ERRORES ---", errores);
		$finish;
	end

endmodule
