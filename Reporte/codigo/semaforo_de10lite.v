// Top-level para la tarjeta Terasic DE10-Lite (MAX 10 10M50DAF484C7G)
// Entradas:
//   KEY[0] = reset (activo en bajo)
//   KEY[1] = boton peatonal
//   SW[0]  = sensor de autos en la calle secundaria
//   SW[1]  = modo emergencia (todos los semaforos en rojo)
// Salidas:
//   LEDR[9:7] = Avenida   (rojo, amarillo, verde)
//   LEDR[6:4] = Calle     (rojo, amarillo, verde)
//   LEDR[3:2] = Peatones  (rojo, verde)
//   LEDR[1]   = solicitud peatonal pendiente
//   LEDR[0]   = latido de 1 segundo
//   HEX1 HEX0 = segundos restantes, HEX3 = fase (1-5, E = emergencia)
//   GPIO[7:0] = LEDs de colores en protoboard (conector JP1, pines 1 a 8):
//               GPIO[0] avenida rojo     GPIO[3] calle rojo     GPIO[6] peaton rojo
//               GPIO[1] avenida amarillo GPIO[4] calle amarillo GPIO[7] peaton verde
//               GPIO[2] avenida verde    GPIO[5] calle verde
//               (cada LED: GPIO -> resistencia -> anodo, catodo -> GND en el pin 12)
module semaforo_de10lite #(
	parameter TICK_DIV  = 12_500_000,  // 1 segundo con reloj de 12.5 MHz
	parameter DIV_RELOJ = 2,           // 50 MHz / 2^2 = 12.5 MHz
	parameter ROM_FILE  = "programa_semaforo.hex"
	)(
	input 		 MAX10_CLK1_50,
	input  [1:0] KEY,
	input  [9:0] SW,
	output [9:0] LEDR,
	output [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
	output [7:0] GPIO
	);

	wire 		clk_cpu;
	wire 		rst = KEY[0];
	wire [9:0] 	leds;
	wire [6:0] 	cuenta;
	wire [3:0] 	fase, decenas, unidades;
	wire 		ped_pendiente, latido;
	wire [6:0] 	seg0, seg1, seg3;
	wire [31:0] pc_actual, instr_actual;
	wire [3:0] 	estado;

	// Reloj del procesador
	divisor_reloj #(.N(DIV_RELOJ)) DIV_CLK (
		.clk_in(MAX10_CLK1_50), .rst(rst), .clk_out(clk_cpu));

	// Sistema del semaforo
	semaforo_soc #(.TICK_DIV(TICK_DIV), .ROM_FILE(ROM_FILE)) SOC (
		.clk(clk_cpu), .rst(rst), .sw(SW), .btn_peaton_n(KEY[1]),
		.leds(leds), .cuenta(cuenta), .fase(fase),
		.ped_pendiente(ped_pendiente), .latido(latido),
		.pc_actual(pc_actual), .instr_actual(instr_actual), .estado(estado));

	// LEDs: el programa controla LEDR[9:2], el hardware LEDR[1:0]
	assign LEDR = {leds[9:2], ped_pendiente, latido};

	// Protoboard: las mismas luces del semaforo hacia LEDs de colores reales
	//              peaton V,  peaton R,  calle V,  calle A,  calle R,  av V,     av A,     av R
	assign GPIO = {leds[2],   leds[3],   leds[4],  leds[5],  leds[6],  leds[7],  leds[8],  leds[9]};

	// Displays de 7 segmentos
	bin_a_bcd BCD (.bin(cuenta), .decenas(decenas), .unidades(unidades));

	decodificador_7seg D0 (.num(unidades), .en(1'b1),          .seg(seg0));
	decodificador_7seg D1 (.num(decenas),  .en(1'b1),          .seg(seg1));
	decodificador_7seg D3 (.num(fase),     .en(fase != 4'd0),  .seg(seg3));

	// El bit 7 es el punto decimal (apagado = 1)
	assign HEX0 = {1'b1, seg0};
	assign HEX1 = {1'b1, seg1};
	assign HEX2 = 8'hFF;
	assign HEX3 = {1'b1, seg3};
	assign HEX4 = 8'hFF;
	assign HEX5 = 8'hFF;

endmodule
