// Sistema completo del semaforo inteligente (procesador + memorias + perifericos)
// Mapa de memoria:
//   0x000 - 0x07F : RAM de datos (32 palabras)
//   0x400 - 0x417 : perifericos (ver perifericos_io.v)
module semaforo_soc #(
	parameter TICK_DIV = 12_500_000,            // ciclos de reloj por segundo
	parameter ROM_FILE = "programa_semaforo.hex"
	)(
	input 		  clk, rst,
	input  [9:0]  sw,
	input 		  btn_peaton_n,
	output [9:0]  leds,
	output [6:0]  cuenta,
	output [3:0]  fase,
	output 		  ped_pendiente,
	output 		  latido,
	// Para depurar
	output [31:0] pc_actual,
	output [31:0] instr_actual,
	output [3:0]  estado
	);

	wire [31:0] mem_addr, mem_wdata, mem_rdata, ram_rdata, io_rdata;
	wire 		mem_we, tick, tick_pendiente;

	// Procesador
	procesador_riscv #(.ROM_ADDR(7), .ROM_FILE(ROM_FILE)) CPU (
		.clk(clk), .rst(rst),
		.mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_we(mem_we), .mem_rdata(mem_rdata),
		.pc_actual(pc_actual), .instr_actual(instr_actual), .estado(estado));

	// Decodificador de direcciones: el bit 10 (0x400) selecciona perifericos
	wire sel_io = mem_addr[10];

	// RAM de datos (ram de clase, corregida)
	ram #(.addr_width(5), .data_width(32)) RAM (
		.clk(clk), .we(mem_we & ~sel_io), .addr(mem_addr[6:2]),
		.data_in(mem_wdata), .data_out(ram_rdata));

	// Tick de 1 segundo
	divisor_tick #(.DIV(TICK_DIV)) TICK (
		.clk(clk), .rst(rst), .tick(tick), .latido(latido));

	// Perifericos
	perifericos_io IO (
		.clk(clk), .rst(rst), .we(mem_we & sel_io), .reg_sel(mem_addr[4:2]),
		.data_in(mem_wdata), .data_out(io_rdata),
		.sw(sw), .btn_peaton_n(btn_peaton_n), .tick(tick),
		.leds(leds), .cuenta(cuenta), .fase(fase),
		.ped_pendiente(ped_pendiente), .tick_pendiente(tick_pendiente));

	// Dato que lee el procesador
	assign mem_rdata = sel_io ? io_rdata : ram_rdata;

endmodule
