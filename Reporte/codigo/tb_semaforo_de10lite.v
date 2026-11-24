`timescale 1ns / 1ps

// Testbench del sistema completo (top-level de la DE10-Lite).
// Para que la simulacion sea corta, un "segundo" dura TICK ciclos del
// procesador en lugar de 12,500,000.
module tb_semaforo_de10lite;

	reg 		clk;
	reg  [1:0] 	KEY;
	reg  [9:0] 	SW;
	wire [9:0] 	LEDR;
	wire [7:0] 	HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

	localparam TICK  = 200;          // ciclos del procesador por segundo simulado
	localparam T_SEG = TICK * 80;    // ns por segundo simulado (reloj CPU = 80 ns)

	// Codigos de luces (LEDR[9:2])
	localparam [7:0] L_AV_VERDE    = 8'b0011_0010,  // 0x0C8 >> 2
	                 L_AV_AMARILLO = 8'b0101_0010,  // 0x148 >> 2
	                 L_CA_VERDE    = 8'b1000_0110,  // 0x218 >> 2
	                 L_CA_AMARILLO = 8'b1000_1010,  // 0x228 >> 2
	                 L_PEATONES    = 8'b1001_0001,  // 0x244 >> 2
	                 L_EMERGENCIA  = 8'b1001_0010;  // 0x248 >> 2

	integer errores;
	integer log;   // archivo de resultados (canal 1 = consola tambien)

	// Unidad bajo prueba
	semaforo_de10lite #(.TICK_DIV(TICK), .DIV_RELOJ(2), .ROM_FILE("src/programa_semaforo.hex")) dut (
		.MAX10_CLK1_50(clk), .KEY(KEY), .SW(SW), .LEDR(LEDR),
		.HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));

	always #10 clk = ~clk;  // 50 MHz

	// Senales para la waveform
	wire [2:0] avenida    = LEDR[9:7];   // R A V
	wire [2:0] calle      = LEDR[6:4];   // R A V
	wire [1:0] peaton     = LEDR[3:2];   // R V
	wire 	   solicitud  = LEDR[1];
	wire 	   latido     = LEDR[0];
	wire [3:0] fase       = dut.fase;
	wire [6:0] cuenta     = dut.cuenta;
	wire [31:0] pc        = dut.pc_actual;
	wire sensor_autos     = SW[0];
	wire emergencia       = SW[1];
	wire boton_peaton     = KEY[1];

	// Espera a que el semaforo llegue a la fase f (con limite de tiempo)
	task esperar_fase(input [3:0] f, input integer max_seg);
		integer t;
		begin
			t = 0;
			while (fase !== f && t < max_seg * T_SEG) begin
				#20; t = t + 20;
			end
			if (fase !== f) begin
				errores = errores + 1;
				$fdisplay(log, "ERROR t=%t: no se llego a la fase %h (fase actual %h)", $time, f, fase);
			end else
				$fdisplay(log, "t=%t: fase %h", $time, f);
			#200;  // da tiempo a que el programa escriba las luces
		end
	endtask

	task revisar_luces(input [7:0] esperado, input [8*14:1] nombre);
		begin
			if (LEDR[9:2] !== esperado) begin
				errores = errores + 1;
				$fdisplay(log, "ERROR: luces %0s = %b, se esperaba %b", nombre, LEDR[9:2], esperado);
			end else
				$fdisplay(log, "OK   : luces %0s  AV=%b CALLE=%b PEATON=%b", nombre, avenida, calle, peaton);
		end
	endtask

	task revisar(input condicion, input [8*48:1] mensaje);
		begin
			if (!condicion) begin
				errores = errores + 1;
				$fdisplay(log, "ERROR: %0s", mensaje);
			end else
				$fdisplay(log, "OK   : %0s", mensaje);
		end
	endtask

	initial begin
		clk = 0; KEY = 2'b10; SW = 10'b0;   // KEY[0]=0 -> reset
		errores = 0;
		log = $fopen("resultados_tb_semaforo_de10lite.txt") | 1;
		$timeformat(-6, 1, " us", 10);  // tiempos en microsegundos
		$fdisplay(log, "--- INICIANDO PRUEBA DEL SEMAFORO INTELIGENTE ---");
		#400 KEY[0] = 1'b1;

		// ---------- 1. Arranque: avenida en verde ----------
		$fdisplay(log, "\n[1] Arranque");
		esperar_fase(4'd1, 1);
		revisar_luces(L_AV_VERDE, "AV_VERDE");
		wait (cuenta == 7'd10); #100;
		revisar(HEX1 == 8'b11111001 && HEX0 == 8'b11000000, "displays muestran 10");
		revisar(HEX3 == 8'b11111001, "HEX3 muestra la fase 1");

		// ---------- 2. Sin autos: la avenida se queda en verde ----------
		$fdisplay(log, "\n[2] Sin autos en la calle");
		#(14 * T_SEG);
		revisar(fase == 4'd1 && cuenta == 7'd0, "sin autos la avenida sigue en verde");

		// ---------- 3. Llega un auto a la calle ----------
		$fdisplay(log, "\n[3] Sensor de autos activado (SW[0]=1)");
		SW[0] = 1'b1;
		esperar_fase(4'd2, 1);
		revisar_luces(L_AV_AMARILLO, "AV_AMARILLO");
		esperar_fase(4'd3, 4);
		revisar_luces(L_CA_VERDE, "CALLE_VERDE");
		SW[0] = 1'b0;
		esperar_fase(4'd4, 9);
		revisar_luces(L_CA_AMARILLO, "CALLE_AMARILLO");
		esperar_fase(4'd1, 4);
		revisar_luces(L_AV_VERDE, "AV_VERDE");

		// ---------- 4. Peaton presiona el boton ----------
		$fdisplay(log, "\n[4] Boton peatonal (KEY[1])");
		#(2 * T_SEG);
		KEY[1] = 1'b0; #500; KEY[1] = 1'b1;   // pulso del boton
		#1000;
		revisar(LEDR[1] == 1'b1, "LEDR[1] indica solicitud peatonal");
		#(T_SEG / 2);
		revisar(cuenta <= 7'd3, "el boton recorta el verde a 3 s");
		esperar_fase(4'd2, 4);
		revisar_luces(L_AV_AMARILLO, "AV_AMARILLO");
		esperar_fase(4'd5, 4);
		revisar_luces(L_PEATONES, "PEATONES");
		revisar(LEDR[1] == 1'b0, "la solicitud se borra al atenderla");
		esperar_fase(4'd1, 8);
		revisar_luces(L_AV_VERDE, "AV_VERDE");

		// ---------- 5. Emergencia ----------
		$fdisplay(log, "\n[5] Emergencia (SW[1]=1)");
		#(3 * T_SEG);
		SW[1] = 1'b1;
		esperar_fase(4'hE, 1);
		revisar_luces(L_EMERGENCIA, "EMERGENCIA");
		revisar(HEX3 == 8'b10000110, "HEX3 muestra E");
		#(4 * T_SEG);
		revisar(fase == 4'hE, "sigue en emergencia mientras SW[1]=1");
		SW[1] = 1'b0;
		esperar_fase(4'd1, 1);
		revisar_luces(L_AV_VERDE, "AV_VERDE");

		// ---------- 6. Estadisticas guardadas en la RAM ----------
		$fdisplay(log, "\n[6] Estadisticas en RAM");
		revisar(dut.SOC.RAM.ram_data[0] == 32'd1, "RAM[0]: 1 cruce peatonal");
		revisar(dut.SOC.RAM.ram_data[1] == 32'd1, "RAM[1]: 1 emergencia");
		revisar(dut.SOC.RAM.ram_data[2] == 32'd1, "RAM[2]: 1 ciclo de la calle");

		#(2 * T_SEG);
		if (errores == 0) $fdisplay(log, "\n--- SEMAFORO: TODAS LAS PRUEBAS PASARON ---");
		else              $fdisplay(log, "\n--- SEMAFORO: %0d ERRORES ---", errores);
		$finish;
	end

endmodule
