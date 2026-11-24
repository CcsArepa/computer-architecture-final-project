module adder_nbits #( // Cuando lleva el numeral significa parameter
	parameter nbits = 32)
	(
	input [nbits-1:0] a, b, 
	output [nbits-1:0] out1);
	
	assign out1 = a + b;
endmodule

	