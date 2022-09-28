`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/07/2020 02:25:09 PM
// Design Name: 
// Module Name: tl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// State costants
`define ST_0        0
`define ST_1        1
`define ST_2        2
`define ST_3        3
`define ST_4        4
`define ST_5        5


module tl(
    input wire [32-1:0] op1,   
    input wire [32-1:0] op2,
    input wire [1:0] in_rdy,
    output reg [32-1:0] res,
    output reg [1:0] res_rdy,
    input wire clk,
    input wire rst  
);

    // Signal
    reg [32-1:0] tmp;
    reg [5:0] state = `ST_0;
    reg [5:0] next_state = `ST_0;

    // Verilog component
    wire [32-1:0] res_verilog;
    wire res_verilog_rdy;
    multiplier_ieee_754_verilog verilog_multiplier(
        .op1(op1),
        .op2(op2),
        .in_rdy(in_rdy[0]),
        .res(res_verilog),
        .res_rdy(res_verilog_rdy),
        .clk(clk),
        .rst(rst)
    );
    
    // VHDL component
    wire [32-1:0] res_vhdl;
    wire res_vhdl_rdy;
    multiplier_ieee_754_vhdl vhdl_multiplier(
        .op1(op1),
        .op2(op2),
        .in_rdy(in_rdy[1]),
        .res(res_vhdl),
        .res_rdy(res_vhdl_rdy),
        .clk(clk),
        .rst(rst)
    );
    
    // FSM
    always @(state, res_verilog_rdy, res_vhdl_rdy) 
    begin 
        case (state)
            `ST_0:
            begin
                next_state <= `ST_1;
            end
            `ST_1:
            begin
                if (res_vhdl_rdy == 1'b1 && res_verilog_rdy == 1'b1)
                    next_state <= `ST_4;
                else if (res_vhdl_rdy == 1'b1)
                    next_state <= `ST_2;
                else if (res_verilog_rdy == 1'b1)
                    next_state <= `ST_3;
                else
                    next_state <= `ST_1;
            end
            `ST_2:
            begin
                next_state <= `ST_1;
            end
            `ST_3:
            begin
                next_state <= `ST_1;
            end
            `ST_4:
            begin
                next_state <= `ST_5;
            end
            `ST_5:
            begin
                next_state <= `ST_0;
            end
            default: 
            begin 
                next_state <= `ST_0;
            end
        endcase
    end

    // DATAPATH
    always @(posedge clk, posedge rst) 
    begin
        state <= next_state;
        if (rst == 1'b1)
            begin
                res_rdy  <= 2'b00;
                res     <= 32'd0;
                tmp     <= 32'd0;
            end
        else
            begin
                case (next_state)
                    `ST_0: 
                    begin
                        res_rdy  <= 2'b00;
                        res     <= 32'd0;
                        tmp     <= 32'd0;
                    end
                    `ST_1:
                    begin
                        // Do nothing
                    end
                    `ST_2:
                    begin
                        res_rdy <= 2'b01;
                        res <= res_vhdl;
                    end
                    `ST_3:
                    begin
                        res_rdy <= 2'b10;
                        res <= res_verilog;
                    end
                    `ST_4:
                    begin
                        res_rdy <= 2'b01;
                        res <= res_verilog;
                        tmp <= res_vhdl;
                    end
                    `ST_5:
                    begin
                        res_rdy <= 2'b10;
                        res <= tmp;
                    end
                    default: 
                    begin 
                        // Do nothing
                    end
                endcase
            end
    end
endmodule
