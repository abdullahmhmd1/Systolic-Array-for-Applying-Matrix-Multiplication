

module systolic_array #(parameter DATAWIDTH = 16, // Width of elements in matrix
parameter N_SIZE = 5   // Number of PEs in each row or column
) (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [N_SIZE*DATAWIDTH-1:0] matrix_b_in, // N_SIZE elements, each DATAWIDTH wide
    input wire [N_SIZE*DATAWIDTH-1:0] matrix_a_in, // N_SIZE elements, each DATAWIDTH wide
    output reg valid_out,
    output reg [N_SIZE*2*DATAWIDTH-1:0] matrix_c_out // N_SIZE*2 elements, each DATAWIDTH wide
);
wire [DATAWIDTH-1:0] a_wire [N_SIZE][N_SIZE+1];
wire [DATAWIDTH-1:0] b_wire [N_SIZE+1][N_SIZE];
wire [2*DATAWIDTH-1:0] r_wire [N_SIZE][N_SIZE];
wire [DATAWIDTH-1:0] reg_wire_a [N_SIZE][N_SIZE];
wire [DATAWIDTH-1:0] reg_wire_b [N_SIZE][N_SIZE];
wire [$clog2(N_SIZE)-1:0] sel;
wire [DATAWIDTH*2*N_SIZE-1:0] r_col_wire [N_SIZE];

genvar i, j;
generate
    for (i = 0; i < N_SIZE; i++) begin : row
        for (j = 0; j < N_SIZE; j++) begin : col

            localparam int THIS_MAX_COUNT = N_SIZE+i+j;
            pe #(
                .DATAWIDTH(DATAWIDTH),
                .MAX_COUNT(THIS_MAX_COUNT)
            ) pe_inst (
                .v_in(b_wire[i][j]),
                .h_in(a_wire[i][j]),
                .v_out(b_wire[i+1][j]),
                .h_out(a_wire[i][j+1]),
                .r(r_wire[i][j]),
                .clk(clk),
                .rst_n(rst_n)
            );
        end
    end
endgenerate


// Pipeline registers for matrix_b_in (shift down each cycle)

genvar r_idx, c_idx;
generate
    for (r_idx = 0; r_idx < N_SIZE; r_idx++) begin : row_block
        for (c_idx = 0; c_idx < N_SIZE; c_idx++) begin : col_block///////////////////////////////right
            if (c_idx > N_SIZE - r_idx - 1) begin
                parallel_reg #(.DATAWIDTH(DATAWIDTH)) parallel_reg_instb (
                    .p_in(reg_wire_b[r_idx-1][c_idx]),   // from row above
                    .clk(clk),
                    .rst_n(rst_n),
                    .p_out(reg_wire_b[r_idx][c_idx])    // to current cell
                );
            end

        end
    end
endgenerate

// Connect the last row outputs of parallel_reg_instb to the first row v_in signals (a_wire[0][j])
genvar idx_b;
generate
    for (idx_b = 0; idx_b < N_SIZE; idx_b++) begin : connect_vin_from_regb
        assign b_wire[0][idx_b] = reg_wire_b[N_SIZE-1][idx_b];/////////////////////////////////right
    end
endgenerate



// Connect matrix_b_in to input registers reg_in_wire_b[0][j]
genvar b;
generate
    for (b = 0; b < N_SIZE; b++) begin : connect_matrix_b_input
        assign reg_wire_b[b][N_SIZE - b - 1] = matrix_b_in[b*DATAWIDTH +: DATAWIDTH];
    end
endgenerate



// pipeline registers for matrix_a_in (shift right each cycle)
genvar x_idx, y_idx;
generate
    for (x_idx = 0; x_idx < N_SIZE; x_idx++) begin : x_loop
        for (y_idx = 0; y_idx < N_SIZE; y_idx++) begin : y_loop //////////////////////////////right

             if (y_idx > N_SIZE - x_idx - 1) begin
                parallel_reg #(.DATAWIDTH(DATAWIDTH)) parallel_reg_insta (
                    .p_in(reg_wire_a[x_idx][y_idx-1]), // from above
                    .clk(clk),
                    .rst_n(rst_n),
                    .p_out(reg_wire_a[x_idx][y_idx])
                );
            end

        end
    end
endgenerate





genvar idx_a;
generate
    for (idx_a = 0; idx_a < N_SIZE; idx_a++) begin : connect_vin_from_rega
        assign a_wire[idx_a][0] = reg_wire_a[idx_a][N_SIZE-1];/////////////////////right
    end
endgenerate

genvar a;
generate
    for (a = 0; a < N_SIZE; a++) begin : connect_matrix_a_input
        assign reg_wire_a[N_SIZE - a - 1][a] = matrix_a_in[a*DATAWIDTH +: DATAWIDTH];
    end
endgenerate






control_unit #(.N_SIZE(N_SIZE)) control_unit_inst (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .valid_out(valid_out),
    .sel(sel));


   
genvar col_index, row_index;
generate
    for (col_index = 0; col_index < N_SIZE; col_index = col_index + 1) begin : concat_cols
        wire [N_SIZE*2*DATAWIDTH-1:0] col_concat;

        for (row_index = 0; row_index < N_SIZE; row_index = row_index + 1) begin : row_concat
            assign col_concat[(N_SIZE - row_index)*2*DATAWIDTH - 1 -: 2*DATAWIDTH] = r_wire[row_index][col_index];
        end

        assign r_col_wire[col_index] = col_concat;
    end
endgenerate


// Connect r_col_wire to mux

genvar k;
generate
    for (k = 0; k < N_SIZE; k++) begin : output_mux
        mux_n_to_1 #(.N_SIZE(N_SIZE), .DATAWIDTH(DATAWIDTH)) mux_inst (
            .in(r_col_wire[k]),
            .sel(sel),
            .out(matrix_c_out[(N_SIZE - k)*2*DATAWIDTH - 1 -: 2*DATAWIDTH])
        );
    end
endgenerate



endmodule
/////////////////////////////////////
module pe #(
    parameter DATAWIDTH = 16,
    parameter MAX_COUNT = 5 // Max accumulation cycles for this instance
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [DATAWIDTH-1:0] v_in,
    input  logic [DATAWIDTH-1:0] h_in,
    output logic [DATAWIDTH-1:0] v_out,
    output logic [DATAWIDTH-1:0] h_out,
    output logic [2*DATAWIDTH-1:0] r
);

    logic [2*DATAWIDTH-1:0] acc;
    logic [$clog2(MAX_COUNT+1)-1:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc    <= '0;
            r      <= '0;
            v_out  <= '0;
            h_out  <= '0;
            count  <= '0;
        end else begin
            if (count < MAX_COUNT) begin
                acc <= acc + v_in * h_in;
                count <= count + 1;
            end
            r <= acc;
            v_out <= v_in;
            h_out <= h_in;
        end
    end
endmodule







module parallel_reg #(//********************//
    parameter DATAWIDTH = 16 // Width of the data
)
(
    input wire [DATAWIDTH-1:0] p_in,
    input wire clk,
    input wire rst_n, 
    output reg [DATAWIDTH-1:0] p_out
);
reg [DATAWIDTH-1:0] p_reg=0;
    //Output the registered value
   always@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
    p_reg<=0;
    p_out<=0;
    end
    else begin
    p_reg = p_in; // Register the input value
   p_out = p_reg; // Register the input value
   end 
   end 


endmodule

module control_unit #( /////*****************//
    parameter N_SIZE  // Number of states in the FSM
    
    )(
    input wire clk,
    input wire rst_n,
    input logic valid_in,
    output logic valid_out,
    output logic [$clog2(N_SIZE)-1:0]sel
);
localparam NUM_STATES = 3*(N_SIZE)-1;
localparam  STATE_WIDTH = $clog2(NUM_STATES);
localparam SEL_WIDTH = $clog2(NUM_STATES/2);
logic [STATE_WIDTH:0] current_state, next_state;

   
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= 0;
        else
            current_state <= next_state;
    end
    always_comb begin
    // Default assignments to avoid latches
    next_state = current_state;
    valid_out  = 0;
    sel = {SEL_WIDTH{1'bx}};  // Assign unknown 'x' to all bits of `sel`

    // Next state logic
   
        if (current_state == NUM_STATES )
            next_state = 0;
        else
            next_state = current_state + 1;
    

    // Output logic
    if (current_state <= (NUM_STATES / 2)+1) begin
        valid_out = 0;
        sel = {SEL_WIDTH{1'bx}};  // Assign unknown 'x' to all bits of `sel`
    end else begin
        
        valid_out = 1;
        sel = (NUM_STATES ) - current_state;
    end
end

endmodule





module mux_n_to_1 #(//*****************//
    parameter N_SIZE = 5,                     // number of inputs
    parameter DATAWIDTH = 16             // width of each input
)(
    input  logic [N_SIZE*2*DATAWIDTH-1:0] in,   // flattened array of inputs
    input  logic [$clog2(N_SIZE)-1:0] sel,    // select line
    output logic [2*DATAWIDTH-1:0] out     // selected output
);

    always_comb begin
        out = 0;
        for (int i = 0; i < N_SIZE; i++) begin
            if ((sel) == i)
                out = in[i*2*DATAWIDTH +: 2*DATAWIDTH];

        end
    end

endmodule
