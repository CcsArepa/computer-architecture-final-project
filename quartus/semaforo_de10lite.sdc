# Restricciones de tiempo para la DE10-Lite
# Reloj de la tarjeta: 50 MHz
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports {MAX10_CLK1_50}]

# Reloj del procesador: 50 MHz / 4 = 12.5 MHz (bit 1 del divisor)
create_generated_clock -name clk_cpu -source [get_ports {MAX10_CLK1_50}] -divide_by 4 \
	[get_registers {divisor_reloj:DIV_CLK|contador[1]}]

derive_clock_uncertainty

# Botones, switches, LEDs y displays son asincronos (los humanos son lentos)
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*]}]
