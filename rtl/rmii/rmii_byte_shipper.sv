`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:     Phantom Motorsports
//              www.phantomtuned.com
// Engineer:    Artin Isagholian
// 
// Create Date: 04/22/2023
// Design Name: 
// Module Name: rmii_byte_shipper
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
module rmii_byte_shipper#(
    parameter logic [1:0]   SPEED_CODE_100_MEGABIT  = 1,
    parameter logic [1:0]   SPEED_CODE_10_MEGABIT   = 0
)(
    input   wire            clock,
    input   wire            reset_n,
    input   wire    [8:0]   data,
    input   wire            data_enable,
    input   wire    [1:0]   speed_code,

    output  reg     [1:0]   shipped_data,
    output  reg             shipped_data_valid,
    output  logic           data_ready
);


typedef enum
{
    S_IDLE,
    S_SEND_PREMABLE,
    S_SEND_START_OF_FRAME,
    S_SEND_DATA,
    S_RESTART
} state_type;

state_type      state;
state_type      _state;
reg     [15:0]  counter;
logic   [15:0]  _counter;
reg     [7:0]   sample_counter;
logic   [7:0]   _sample_counter;
logic   [1:0]   _shipped_data;
logic           _shipped_data_valid;
logic   [7:0]   _byte_to_ship;
reg     [7:0]   byte_to_ship;
reg     [7:0]   sample_counter_limit;
logic   [7:0]   _sample_counter_limit;
reg     [15:0]  preamble_count_limit;
logic   [15:0]  _preamble_count_limit;
reg     [1:0]   saved_speed_code;
logic   [1:0]   _saved_speed_code;

always_comb  begin
    _state                  =   state;
    _counter                =   counter;
    _byte_to_ship           =   byte_to_ship;
    _sample_counter         =   sample_counter;
    _shipped_data           =   shipped_data;
    _shipped_data_valid     =   shipped_data_valid;
    _sample_counter_limit   =   sample_counter_limit;
    _preamble_count_limit   =   preamble_count_limit;
    _saved_speed_code       =   saved_speed_code;
    data_ready              =   0;

    case (saved_speed_code)
        SPEED_CODE_100_MEGABIT: begin
            _sample_counter_limit   =   0;
            _preamble_count_limit   =   29;
        end
        SPEED_CODE_10_MEGABIT: begin
            _sample_counter_limit   =   9;
            _preamble_count_limit   =   290;
        end
        default : begin
            _sample_counter_limit   =   0;
            _preamble_count_limit   =   29;
        end
    endcase

    case (state)
        S_IDLE: begin
            _shipped_data_valid =   0;
            _saved_speed_code   =   speed_code;

            if (data_enable) begin
                data_ready              =   1;

                if (data[8]) begin
                    _byte_to_ship       =   data[7:0];
                    _counter            =   0;
                    _shipped_data       =   2'b01;
                    _shipped_data_valid =   1;
                    _state              =   S_SEND_PREMABLE;
                end
            end
        end
        S_SEND_PREMABLE: begin
            if (counter < preamble_count_limit) begin
                _counter = counter + 1;
            end
            else begin
                _counter    =   0;

                if (sample_counter == sample_counter_limit) begin
                    _sample_counter     =   0;
                    _state              =   S_SEND_START_OF_FRAME;
                end
                else begin
                    _sample_counter =   sample_counter + 1;
                end
            end
        end
        S_SEND_START_OF_FRAME: begin
            _counter           =   0;
            _shipped_data      =   2'b11;

            if (sample_counter == sample_counter_limit) begin
                _sample_counter =   0;
                _state          =   S_SEND_DATA;
            end
            else begin
                _sample_counter =   sample_counter + 1;
            end
        end
        S_SEND_DATA: begin
            _shipped_data   =   byte_to_ship[1:0];

            if (sample_counter >= sample_counter_limit) begin

                _sample_counter =   0;
                _byte_to_ship   =   {2'b00,byte_to_ship[7:2]};

                if (counter < 4) begin
                    _counter        = counter + 1;
                end
                else begin
                    _counter        =   1;
                end

                if (counter == 3) begin
                    if (data_enable) begin
                        if (data[8]) begin
                            _state          =   S_IDLE;
                        end
                        else begin
                            _byte_to_ship   =   data[7:0];
                            data_ready      =   1;
                        end
                    end
                    else begin
                        _state              =   S_IDLE;
                    end
                end
            end
            else begin
                _sample_counter =   sample_counter + 1;
            end
        end
    endcase
end

always_ff @(posedge clock) begin
    if (!reset_n) begin
        state                   <=  S_IDLE;
        counter                 <=  0;
        shipped_data            <=  0;
        shipped_data_valid      <=  0;
        byte_to_ship            <=  0;
        sample_counter          <=  0;
        sample_counter_limit    <=  0;
        preamble_count_limit    <=  0;
        saved_speed_code        <=  0;
    end
    else begin
        state                   <=  _state;
        counter                 <=  _counter;
        sample_counter          <=  _sample_counter;
        sample_counter_limit    <=  _sample_counter_limit;
        shipped_data            <=  _shipped_data;
        shipped_data_valid      <=  _shipped_data_valid;
        byte_to_ship            <=  _byte_to_ship;
        preamble_count_limit    <=  _preamble_count_limit;
        saved_speed_code        <=  _saved_speed_code;
    end
end

endmodule