module pipo_register #(
    parameter nbits = 32,
    parameter INIT_VALUE = 32'h00000000
)(
    input clk,
    input rst,
    input enable,
    input [nbits-1:0] d,
    output [nbits-1:0] q
);

    reg [nbits-1:0] qaux;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            qaux <= INIT_VALUE;
        end
        else if (enable) begin
            qaux <= d;
        end
    end

    assign q = qaux;

endmodule
