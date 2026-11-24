`timescale 1ns / 1ps

// Testbench del procesador: ejecuta prueba_instrucciones.hex y compara
// el contenido final de los registros y de la RAM contra lo esperado.
module tb_procesador_riscv;

	reg 		clk, rst;
	wire [31:0] mem_addr, mem_wdata, mem_rdata;
	wire 		mem_we;
	wire [31:0] pc_actual, instr_actual;
	wire [3:0] 	estado;

	integer errores, ciclos, instrucciones;
	integer log;   // archivo de resultados (canal 1 = consola tambien)

	// Unidad bajo prueba
	procesador_riscv #(.ROM_ADDR(7), .ROM_FILE("src/prueba_instrucciones.hex")) uut (
		.clk(clk), .rst(rst),
		.mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_we(mem_we), .mem_rdata(mem_rdata),
		.pc_actual(pc_actual), .instr_actual(instr_actual), .estado(estado));

	// Memoria de datos
	ram #(.addr_width(5), .data_width(32)) memoria (
		.clk(clk), .we(mem_we), .addr(mem_addr[6:2]),
		.data_in(mem_wdata), .data_out(mem_rdata));

	always #5 clk = ~clk;   // reloj de 100 MHz

	// Senales internas para la waveform
	wire [31:0] x1  = uut.RF.regs[1];
	wire [31:0] x3  = uut.RF.regs[3];
	wire [31:0] x9  = uut.RF.regs[9];
	wire [31:0] x22 = uut.RF.regs[22];
	wire [31:0] x23 = uut.RF.regs[23];
	wire [31:0] alu_result = uut.alu_result;
	wire 		reg_write  = uut.reg_write;
	wire 		pc_write   = uut.pc_write;

	// Traza: muestra cada instruccion cuando se decodifica
	always @(posedge clk) begin
		if (rst && estado == 4'd1) begin
			instrucciones = instrucciones + 1;
			$fdisplay(log, "t=%t  PC=%h  INSTR=%h", $time, pc_actual, instr_actual);
		end
	end

	task revisar_reg(input [4:0] r, input [31:0] esperado);
		begin
			if (uut.RF.regs[r] !== esperado) begin
				errores = errores + 1;
				$fdisplay(log, "ERROR: x%0d = %h, se esperaba %h", r, uut.RF.regs[r], esperado);
			end else
				$fdisplay(log, "OK   : x%0d = %h (%0d)", r, uut.RF.regs[r], $signed(uut.RF.regs[r]));
		end
	endtask

	task revisar_ram(input [4:0] dir, input [31:0] esperado);
		begin
			if (memoria.ram_data[dir] !== esperado) begin
				errores = errores + 1;
				$fdisplay(log, "ERROR: RAM[%0d] = %h, se esperaba %h", dir, memoria.ram_data[dir], esperado);
			end else
				$fdisplay(log, "OK   : RAM[%0d] = %h (%0d)", dir, memoria.ram_data[dir], memoria.ram_data[dir]);
		end
	endtask

	initial begin
		clk = 0; rst = 0;
		errores = 0;
		log = $fopen("resultados_tb_procesador_riscv.txt") | 1; instrucciones = 0;
		$timeformat(-9, 0, " ns", 8);   // tiempos en nanosegundos
		$fdisplay(log, "--- INICIANDO PRUEBA DEL PROCESADOR RISC-V ---");
		#20 rst = 1;

		// Esperamos a que el programa llegue a FIN (0x98)
		ciclos = 0;
		while (!(pc_actual == 32'h98 && estado == 4'd1) && ciclos < 1000) begin
			@(posedge clk);
			ciclos = ciclos + 1;
		end
		#20;
		$fdisplay(log, "\nEl programa llego a FIN en %0d ciclos (%0d instrucciones decodificadas)\n", ciclos, instrucciones);

		revisar_reg(5'd1,  32'h00000070);  // jal x1 -> direccion de regreso
		revisar_reg(5'd2,  32'd10);
		revisar_reg(5'd3,  32'd25);        // add
		revisar_reg(5'd4,  32'd5);         // sub
		revisar_reg(5'd5,  32'd10);        // and
		revisar_reg(5'd6,  32'd15);        // or
		revisar_reg(5'd7,  32'd5);         // xor
		revisar_reg(5'd8,  32'd1);         // slt
		revisar_reg(5'd9,  32'd150);       // mul
		revisar_reg(5'd10, 32'hFFFFFFFD);  // addi -3
		revisar_reg(5'd11, 32'd1);         // slti
		revisar_reg(5'd12, 32'd240);       // slli
		revisar_reg(5'd13, 32'hFFFFFFFE);  // srai
		revisar_reg(5'd14, 32'd60);        // srli
		revisar_reg(5'd15, 32'd6);         // andi
		revisar_reg(5'd16, 32'd15);        // ori
		revisar_reg(5'd17, 32'd240);       // xori
		revisar_reg(5'd18, 32'h12345000);  // lui
		revisar_reg(5'd19, 32'd25);        // lw
		revisar_reg(5'd20, 32'd1);         // beq tomado
		revisar_reg(5'd21, 32'd7);         // bne no tomado, blt tomado
		revisar_reg(5'd22, 32'd6);         // jal / jalr
		revisar_reg(5'd23, 32'd15);        // lazo
		revisar_reg(5'd24, 32'd0);
		revisar_reg(5'd0,  32'd0);         // x0 siempre 0
		revisar_ram(5'd2,  32'd25);        // sw
		revisar_ram(5'd3,  32'd15);

		if (errores == 0) $fdisplay(log, "\n--- PROCESADOR: TODAS LAS PRUEBAS PASARON ---");
		else              $fdisplay(log, "\n--- PROCESADOR: %0d ERRORES ---", errores);
		$finish;
	end

endmodule
