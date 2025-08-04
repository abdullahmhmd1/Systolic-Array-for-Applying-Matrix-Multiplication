module systolic_array_tb;

    parameter DATAWIDTH = 16;
    parameter N_SIZE = 5;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg [N_SIZE*DATAWIDTH-1:0] matrix_a_in;
    reg [N_SIZE*DATAWIDTH-1:0] matrix_b_in;
    wire valid_out;
    wire [N_SIZE*2*DATAWIDTH-1:0] matrix_c_out;

    systolic_array #(
        .DATAWIDTH(DATAWIDTH),
        .N_SIZE(N_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .matrix_a_in(matrix_a_in),
        .matrix_b_in(matrix_b_in),
        .valid_out(valid_out),
        .matrix_c_out(matrix_c_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
       
        rst_n = 0;
       matrix_a_in = {16'h0001, 16'h0000, 16'h0000 , 16'h0000, 16'h0000};
        matrix_b_in = {16'h0001, 16'h0002, 16'h0003 , 16'h0004, 16'h0005};
        valid_in = 1;
        #10;
        rst_n = 1;
         
        
        // Provide valid input
       

        #10;
        matrix_a_in = {16'h0000, 16'h0001, 16'h0000, 16'h0000, 16'h0000};
        matrix_b_in = { 16'h0006, 16'h0007, 16'h0008, 16'h0009, 16'h000a};
        #10;
        matrix_a_in = {16'h0000, 16'h0000, 16'h0001 , 16'h0000, 16'h0000};
        matrix_b_in = { 16'h000b, 16'h000c , 16'h000d, 16'h000e, 16'h000f};
        #10;
        matrix_a_in = {16'h0000, 16'h0000, 16'h0000, 16'h0001, 16'h0000};
        matrix_b_in = { 16'h0010, 16'h0011, 16'h0012, 16'h0013, 16'h0014};
         #10;
        matrix_a_in = {16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0001};
        matrix_b_in = { 16'h0015, 16'h0016, 16'h0017, 16'h0018, 16'h0019};
        #60;
        $display("Output Matrix C: %h", matrix_c_out);
#10;
        $display("Output Matrix C: %h", matrix_c_out);
 #10
        $display("Output Matrix C: %h", matrix_c_out);
 #10;
        $display("Output Matrix C: %h", matrix_c_out);
 #10;
        $display("Output Matrix C: %h", matrix_c_out);
 
        $finish;
    end

endmodule
