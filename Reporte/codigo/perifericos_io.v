// Perifericos mapeados en memoria del semaforo inteligente
// El procesador los ve como direcciones a partir de 0x400:
//   0x400 LEDS     (W) luces del semaforo -> LEDR[9:2]
//   0x404 CUENTA   (W) segundos restantes -> HEX1 HEX0
//   0x408 FASE     (W) fase actual        -> HEX3
//   0x40C SWITCHES (R) SW[0] = sensor de autos, SW[1] = emergencia
//   0x410 PEATON   (R) 1 = hay solicitud peatonal, (W) cualquier valor la borra
//   0x414 TICK     (R) 1 = ya paso un segundo,     (W) cualquier valor lo borra
module perifericos_io (
	input 			  clk, rst,
	input 			  we,            // escritura desde el procesador
	input 	   [2:0]  reg_sel,       // direccion del registro (addr[4:2])
	input 	   [31:0] data_in,
	output reg [31:0] data_out,
	// Entradas de la tarjeta
	input 	   [9:0]  sw,
	input 			  btn_peaton_n,  // KEY[1], activo en bajo
	input 			  tick,          // pulso de 1 segundo
	// Salidas
	output reg [9:0]  leds,
	output reg [6:0]  cuenta,
	output reg [3:0]  fase,
	output reg 		  ped_pendiente,
	output reg 		  tick_pendiente
	);

	localparam R_LEDS   = 3'd0,
	           R_CUENTA = 3'd1,
	           R_FASE   = 3'd2,
	           R_SW     = 3'd3,
	           R_PEATON = 3'd4,
	           R_TICK   = 3'd5;

	// Sincronizadores (2 flip-flops) para entradas asincronas de la tarjeta
	reg [9:0] sw_s1, sw_s2;
	reg 	  btn_s1, btn_s2, btn_s3;

	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			sw_s1  <= 10'b0;
			sw_s2  <= 10'b0;
			btn_s1 <= 1'b1;
			btn_s2 <= 1'b1;
			btn_s3 <= 1'b1;
		end else begin
			sw_s1  <= sw;
			sw_s2  <= sw_s1;
			btn_s1 <= btn_peaton_n;
			btn_s2 <= btn_s1;
			btn_s3 <= btn_s2;
		end
	end

	// Flanco de bajada del boton = el peaton lo acaba de presionar
	wire btn_presionado = btn_s3 & ~btn_s2;

	// Escritura de registros
	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			leds 		   <= 10'b0;
			cuenta 		   <= 7'd0;
			fase 		   <= 4'd0;
			ped_pendiente  <= 1'b0;
			tick_pendiente <= 1'b0;
		end else begin
			if (we) begin
				case (reg_sel)
					R_LEDS:   leds   <= data_in[9:0];
					R_CUENTA: cuenta <= data_in[6:0];
					R_FASE:   fase   <= data_in[3:0];
					default: ;
				endcase
			end

			// Solicitud peatonal: se guarda hasta que el programa la borre
			if (btn_presionado)
				ped_pendiente <= 1'b1;
			else if (we && (reg_sel == R_PEATON))
				ped_pendiente <= 1'b0;

			// Bandera de 1 segundo: se guarda hasta que el programa la borre
			if (tick)
				tick_pendiente <= 1'b1;
			else if (we && (reg_sel == R_TICK))
				tick_pendiente <= 1'b0;
		end
	end

	// Lectura sincrona (igual que la RAM)
	always @(posedge clk) begin
		case (reg_sel)
			R_LEDS:   data_out <= {22'b0, leds};
			R_CUENTA: data_out <= {25'b0, cuenta};
			R_FASE:   data_out <= {28'b0, fase};
			R_SW:     data_out <= {22'b0, sw_s2};
			R_PEATON: data_out <= {31'b0, ped_pendiente};
			R_TICK:   data_out <= {31'b0, tick_pendiente};
			default:  data_out <= 32'b0;
		endcase
	end

endmodule
