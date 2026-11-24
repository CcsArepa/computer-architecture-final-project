module mux_4a1 #(parameter n = 8 )(
	input wire [n-1:0] I3, I2, I1, I0, 
	input wire [1:0] Sel,             
	output reg [n-1:0] S
);
    always @(*) begin
        case(Sel)
            2'b00: S = I0;
            2'b01: S = I1;
            2'b10: S = I2;
            2'b11: S = I3;
            default: S = {n{1'b0}}; 
        endcase
    end
endmodule