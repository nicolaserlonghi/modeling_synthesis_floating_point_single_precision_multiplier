`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/07/2020 02:25:09 PM
// Design Name: 
// Module Name: multiplier_ieee_754_verilog
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

// States costants
`define ST_0       0
`define ST_1       1
`define ST_2       2
`define ST_ZERO    3
`define ST_INF     4
`define ST_NAN     5
`define ST_3       6
`define ST_4       10
`define ST_5       11
`define ST_6       12
`define ST_7       13
`define ST_8       14
`define ST_9       15
`define ST_10      16
`define ST_11      17
`define ST_ROUND   18
`define ST_12      19
`define ST_NORM    20
`define ST_DENORM  21
`define ST_OUT     22
`define ST_ERR     23

module multiplier_ieee_754_verilog(
    input wire [32-1:0] op1,
    input wire [32-1:0] op2,
    input wire in_rdy,
    output reg [32-1:0] res,
    output reg res_rdy,
    input wire clk,
    input wire rst
);
    
    parameter SIZE_OF_MANTISSA  = 23;
    parameter SIZE_OF_EXPONENT  = 8;
    
    // Signals
    reg [SIZE_OF_EXPONENT-1:0]  exp;
    reg [SIZE_OF_EXPONENT:0]    tmpexp;
    reg [SIZE_OF_MANTISSA-1:0]  m;
    reg [SIZE_OF_MANTISSA:0]    m1;
    reg [SIZE_OF_MANTISSA:0]    m2;
    reg [((SIZE_OF_MANTISSA+1)*2)-1:0]  tmpm;
    reg s;
    reg [5:0] state = `ST_0;
    reg [5:0] next_state = `ST_0;
    
    
    // FSM
    always @(state, op1, op2, in_rdy, m1, m2, tmpm, tmpexp)
    begin
        case (state)
            `ST_0:
            begin
                // Init or reset
                next_state <= `ST_1;
            end
            `ST_1:
            begin
                // Wait for in_rdy
                if (in_rdy == 1)
                    next_state <= `ST_2;
                else
                    next_state <= `ST_1;
            end 
            `ST_2:
            begin
                // Input dispatch
                if ((op1[30:23] == 8'hFF && m1 != 0) || (op2[30:23] == 8'hFF && m2 != 0))
                    begin
                        // opi or op2 are nan
                        next_state <= `ST_NAN;
                    end
                else if ((op1[30:23] == 8'hFF && m1 == 0 && op2[30:23] == 0 && m2 == 0) 
                  || (op1[30:23] == 0 && m1 == 0 && op2[30:23] == 8'hFF && m2 == 0))
                    begin
                        // op1 is inf and op2 is 0 or the other way around
                        next_state <= `ST_NAN;
                    end
                else if ((op1[30:23] == 8'hFF && m1 == 0) || (op2[30:23] == 8'hFF && m2 == 0))
                    begin
                        // op1 or op2 are inf
                        next_state <= `ST_INF;
                    end
                else if ((op1[30:23] == 0 && m1 == 0) || (op2[30:23] == 0 && m2 == 0))
                    begin
                        // op1 or op2 are zero
                        next_state <= `ST_ZERO;
                    end
                else
                    begin
                        // op1 and/or op2 are normalized or denormalized numbers
                        next_state <= `ST_3;
                    end
            end
            `ST_3:
            begin
                // Manage normalized and denormalized input
                if (op1[30:23] == 0 || op2[30:23] == 0)
                    begin
                        // op1 and op2 are denormalized
                        next_state <= `ST_ERR;
                    end
                else
                    begin
                        // op1 and/or op2 are not normalized
                        next_state <= `ST_4;
                    end 
            end
            `ST_4:
            begin
                // Check if mantissa result is normalized or not
                if (tmpm[47:46] == 2'b10 || tmpm[47:46] == 2'b11)
                    begin
                        // Basic normalizzation
                        next_state <= `ST_5;
                    end
                else if (tmpm[47:46] == 2'b00)
                    begin
                        // Shift normalization
                        next_state <= `ST_6;
                    end
                else // case "10"
                    begin
                        // Already normalized
                        next_state <= `ST_NORM;
                    end
            end
            `ST_5:
            begin
                // Number normalizes
                next_state <= `ST_NORM;
            end
            `ST_6:
            begin
                // Check exponent overflow after shift normaliazzation
                if (tmpexp[8] == 1'b1)
                    begin
                        // Overflow
                        next_state <= `ST_7;
                    end
                else
                    begin
                        // No overflow but can get underflow
                        next_state <= `ST_8;
                    end
            end
            `ST_7:
            begin
                // Manage overflow during multiplication
                if (tmpm[47:46] == 2'b00)
                    begin
                        next_state <= `ST_7;
                    end
                else
                    begin
                        next_state <= `ST_NORM;
                    end
            end
            `ST_8:
            begin
                // Check and manage underflow
                if (tmpexp[8:0] == 0)
                    begin
                        // Underflow
                        next_state <= `ST_DENORM;
                    end
                else if (tmpm[47:46] == 2'b00)
                    begin
                        next_state <= `ST_8;
                    end
                else
                    begin
                        // Finish normalization
                        next_state <= `ST_NORM;
                    end
            end
            `ST_NORM:
            begin
                if (tmpexp[8] == 1'b1)
                    begin
                        next_state <= `ST_INF;
                    end
                else
                    begin
                        next_state <= `ST_9;
                    end
            end
            `ST_DENORM:
             begin
                next_state <= `ST_10;
             end
            `ST_9:
            begin
                next_state <= `ST_10;
            end
            `ST_10:
            begin
                if (tmpm[22] == 1'b0)
                    begin
                        // Prepare result
                        next_state <= `ST_11;
                    end
                else
                    begin
                        next_state <= `ST_ROUND;
                    end
            end
            `ST_11:
            begin
                // Prepare result
                next_state <= `ST_OUT;
            end
            `ST_ROUND:
            begin
                if (tmpm[47:46] == 2'b01)
                    begin
                        next_state <= `ST_12;
                    end
                else
                    begin
                        // Prepare result
                        next_state <= `ST_11;
                    end
            end
            `ST_12:
            begin
                next_state <= `ST_OUT;
            end
            `ST_ZERO:
            begin
                next_state <= `ST_OUT;
            end
            `ST_NAN:
            begin
                next_state <= `ST_OUT;
            end
            `ST_INF:
            begin
                next_state <= `ST_OUT;
            end
            `ST_OUT:
            begin
                next_state <= `ST_0;
            end
            `ST_ERR:
            begin
                next_state <= `ST_0;
            end
            default:
            begin
                next_state <= `ST_0;
            end
        endcase
    end
    
    // Datapath
    always @(posedge clk, posedge rst) 
    begin 
        if(rst == 1'b1)
            begin
                state <= `ST_0;
            end
        else
            begin
                state <= next_state;
                case(next_state)
                    `ST_0: 
                    begin
                        // Reset all
                        m       <= 0;
                        m1      <= 0;
                        m2      <= 0;
                        tmpm    <= 0;
                        tmpexp  <= 0;
                        exp     <= 0;
                        s       <= 0;
                        res <= 0;
                        res_rdy <= 0;
                    end
                    `ST_1:
                    begin
                        // Do nothing
                    end
                    `ST_2:
                    begin
                        m1[22:0] <= op1[22:0];
                        m2[22:0] <= op2[22:0];
                        s <= op1[31] ^ op2[31];
                    end
                    `ST_3:
                    begin
                        m1[23] <= 1'b1;
                        m2[23] <= 1'b1;
                    end
                    `ST_4:
                    begin
                        // sum - bias
                        tmpexp <= op1[30:23] + op2[30:23] - 8'd127;
                        // Mantix multiplication
                        tmpm   <= m1 * m2;
                    end
                    `ST_5:
                    begin
                        tmpm   <= tmpm >> 1;
                        tmpexp <= tmpexp + 9'd1;
                    end
                    `ST_6:
                    begin
                        // Do nothing
                    end
                    `ST_7:
                    begin
                        tmpm   <= tmpm << 1;
                        tmpexp <= tmpexp - 9'd1;
                    end
                    `ST_8:
                    begin
                        tmpm   <= tmpm << 1;
                        tmpexp <= tmpexp - 9'd1;
                    end
                    `ST_NORM:
                    begin
                        // Do nothing
                    end
                    `ST_DENORM:
                    begin
                        exp <= 8'd0;
                    end
                    `ST_9:
                    begin
                        exp <= tmpexp[7:0];
                    end
                    `ST_10:
                    begin
                        // Do nothing
                    end
                    `ST_11:
                    begin
                        m <= tmpm[45:23];
                    end
                    `ST_ROUND:
                    begin
                        tmpm[47:22] <= tmpm[47:22] + 26'd1;
                    end
                    `ST_12:
                    begin
                        tmpexp <= tmpexp + 9'd1;
                    end
                    `ST_NAN:
                    begin
                        exp <= 8'hFF;
                        m   <= {1'b1, 22'b0};
                        s   <= 1'b0;
                    end
                    `ST_INF:
                    begin
                        exp <= 8'hFF;
                        m   <= 23'd0;
                    end
                    `ST_ZERO:
                    begin
                        exp <= 8'h00;
                        m   <= 23'd0;
                    end
                    `ST_OUT:
                    begin
                        res_rdy <= 1'b1;
                        res[31] <= s;
                        res[30:23] <= exp;
                        res[22:0]  <=m;
                    end
                    `ST_ERR:
                    begin
                        res_rdy <= 1'b1;
                        res <= 0;
                        res[30:23] <= exp;
                        res[22:0]  <=m;
                    end
                    default: 
                    begin 
                        // Do nothings
                    end
                endcase
            end
        end
endmodule

