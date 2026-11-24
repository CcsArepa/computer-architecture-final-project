module alu_riscv (
    input  wire [31:0] A, B, C,
    input  wire [6:0]  opcode,        // tipo de instruccion
    input  wire [4:0]  alu_op,        // operacion a realizar
    output reg  [31:0] Result,        
    output wire Carry, Overflow, Zero, Negativo        
);

    // Codigos de operacion de la ALU (Originales - Tipo R)
    localparam ALU_ADD     = 5'b00000;
    localparam ALU_SUB     = 5'b00001;
    localparam ALU_AND     = 5'b00010;
    localparam ALU_OR      = 5'b00011;
    localparam ALU_XOR     = 5'b00100;
    localparam ALU_NOTA    = 5'b00101;
    localparam ALU_SLL     = 5'b00110;
    localparam ALU_SRL     = 5'b00111;
    localparam ALU_PASSB   = 5'b01000; 
    localparam ALU_SRA     = 5'b01001; 
    localparam ALU_ADD_MUL = 5'b01010; // (A+B) * C	
    localparam ALU_MUL     = 5'b01011; // (A*B)

    // 1. Tres para Formato Tipo I (Inmediato / Loads)
    localparam ALU_I_SLTI  = 5'b01100; // Set Less Than Immediate con signo (A < B)
    localparam ALU_I_LW    = 5'b01101; // Load Word: Direccion efectiva A + B
    localparam ALU_I_LB    = 5'b01110; // Load Byte: (A + B) enmascarado a 8 bits

    // 2. Tres para Formato Tipo B (Branch / Saltos condicionales)
    localparam ALU_B_BEQ   = 5'b01111; // Branch Equal (A == B)
    localparam ALU_B_BNE   = 5'b10000; // Branch Not Equal (A != B)
    localparam ALU_B_BLT   = 5'b10001; // Branch Less Than con signo (A < B)

    // 3. Tres para Formato Tipo S (Store / Guardado en memoria)
    localparam ALU_S_SW    = 5'b10010; // Store Word: Direccion A + B
    localparam ALU_S_SH    = 5'b10011; // Store Halfword: A + B alineado a 16 bits
    localparam ALU_S_SB    = 5'b10100; // Store Byte: Direccion A + B + byte de C

    // 4. Tres para Formato Tipo U (Upper Immediate)
    localparam ALU_U_LUI   = 5'b10101; // Load Upper Immediate: B << 12
    localparam ALU_U_AUIPC = 5'b10110; // Add Upper Imm to PC: A + (B << 12)
    localparam ALU_U_LUI16 = 5'b10111; // Load Upper 16 bits: {B[15:0], 16'b0}

    // 5. Tres para Formato Tipo J (Jump / Saltos incondicionales)
    localparam ALU_J_JAL   = 5'b11000; // Jump and Link: PC (A) + Offset (B)
    localparam ALU_J_LINK  = 5'b11001; // Retorno de subrutina: PC (A) + 4
    localparam ALU_J_JALR  = 5'b11010; // Jump and Link Reg: (A + B) & ~1

    // Opcodes
    localparam OP_R = 7'b0110011; // Tipo Registro
    localparam OP_I = 7'b0010011; // Tipo Inmediato
    localparam OP_B = 7'b1100011; // Tipo Branch (salto condicional)

    // Nuevos Opcodes para completar los formatos restantes de RISC-V 
    localparam OP_S = 7'b0100011; // Tipo Store (Guardado en memoria)
    localparam OP_U = 7'b0110111; // Tipo Upper Immediate (Inmediatos largos)
    localparam OP_J = 7'b1101111; // Tipo Jump (Saltos incondicionales)

    // Aritmetica para extender el carry
    wire [32:0] sum_ext = {1'b0, A} + {1'b0, B};
    wire [32:0] sub_ext = {1'b0, A} - {1'b0, B};
    wire [31:0] sum = sum_ext[31:0];
    wire [31:0] sub = sub_ext[31:0];

    // Overflow con signo
    wire ovf_add = (~A[31] & ~B[31] &  sum[31]) | (A[31] &  B[31] & ~sum[31]);
    wire ovf_sub = (~A[31] &  B[31] &  sub[31]) | (A[31] & ~B[31] & ~sub[31]);

    // Cantidad de desplazamiento (RISC-V usa los 5 bits bajos)
    wire [4:0] shamt = B[4:0];

    // Opcode y luego alu_op
    always @(*) begin
        case (opcode)
            // Si es operacion de ALU (R o I)
            OP_R, OP_I: begin
                case (alu_op) 
                    ALU_ADD:     Result = sum;
                    ALU_SUB:     Result = sub;
                    ALU_AND:     Result = A & B;
                    ALU_OR:      Result = A | B;
                    ALU_XOR:     Result = A ^ B;
                    ALU_NOTA:    Result = ~A;
                    ALU_SLL:     Result = A << shamt;
                    ALU_SRL:     Result = A >> shamt;
                    ALU_SRA:     Result = $signed(A) >>> shamt;
                    ALU_PASSB:   Result = B;
                    ALU_ADD_MUL: Result = (A + B) * C;
                    ALU_MUL:     Result = A * B; // A * B

                    // --- 3 Nuevas de Tipo I ---
                    ALU_I_SLTI:  Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
                    ALU_I_LW:    Result = sum;
                    ALU_I_LB:    Result = sum & 32'h000000FF;
                    
                    default:     Result = 32'b0;
                endcase
            end
            
            // Si es un salto condicional (Branch)
            OP_B: begin
                // Las instrucciones tipo B comparan siempre restando
                Result = sub;

                // --- 3 Nuevas de Tipo B ---
                case (alu_op)
                    ALU_B_BEQ: Result = (A == B) ? 32'd1 : 32'd0;
                    ALU_B_BNE: Result = (A != B) ? 32'd1 : 32'd0;
                    ALU_B_BLT: Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
                    default:   Result = sub; // Mantiene el comportamiento original por defecto
                endcase
            end

            // --- Nuevo bloque Formato Tipo S (3 instrucciones) ---
            OP_S: begin
                case (alu_op)
                    ALU_S_SW: Result = sum;                      // Direccion A + Offset B
                    ALU_S_SH: Result = {sum[31:1], 1'b0};        // Alineado a media palabra (16b)
                    ALU_S_SB: Result = sum + (C & 32'h000000FF); // Direccion + byte de C
                    default:  Result = 32'b0;
                endcase
            end

            // --- Nuevo bloque Formato Tipo U (3 instrucciones) ---
            OP_U: begin
                case (alu_op)
                    ALU_U_LUI:   Result = B << 12;               // Carga 20 bits en parte alta
                    ALU_U_AUIPC: Result = A + (B << 12);         // PC (A) + (Inmediato B << 12)
                    ALU_U_LUI16: Result = {B[15:0], 16'b0};      // Carga en mitad superior
                    default:     Result = 32'b0;
                endcase
            end

            // --- Nuevo bloque Formato Tipo J (3 instrucciones) ---
            OP_J: begin
                case (alu_op)
                    ALU_J_JAL:  Result = sum;                    // Salto PC (A) + Offset (B)
                    ALU_J_LINK: Result = A + 32'd4;              // PC + 4 (direccion de retorno)
                    ALU_J_JALR: Result = sum & 32'hFFFFFFFE;     // (A + B) forzando bit 0 a 0
                    default:    Result = 32'b0;
                endcase
            end
            
            // Seguridad para evitar latches
            default: begin
                Result = 32'b0;
            end
        endcase
    end


    // Banderas
    wire [4:0] op_eff = (opcode == OP_B) ? ALU_SUB : alu_op;

    // Carry: carry en suma / borrow en resta (solo para ADD y SUB)
    assign Carry = (op_eff == ALU_ADD) ? sum_ext[32] :
                   (op_eff == ALU_SUB) ? sub_ext[32] : 1'b0;

    // Overflow: overflow con signo (solo para ADD y SUB)
    assign Overflow = (op_eff == ALU_ADD) ? ovf_add : (op_eff == ALU_SUB) ? ovf_sub : 1'b0;
	assign Zero = (Result == 32'b0);
    assign Negativo = Result[31];

endmodule