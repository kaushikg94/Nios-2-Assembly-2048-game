// (C) 2001-2012 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// $Id: //acds/rel/12.0/ip/merlin/altera_merlin_router/altera_merlin_router.sv.terp#1 $
// $Revision: #1 $
// $Date: 2012/02/13 $
// $Author: swbranch $

// -------------------------------------------------------
// Merlin Router
//
// Asserts the appropriate one-hot encoded channel based on 
// either (a) the address or (b) the dest id. The DECODER_TYPE
// parameter controls this behaviour. 0 means address decoder,
// 1 means dest id decoder.
//
// In the case of (a), it also sets the destination id.
// -------------------------------------------------------

`timescale 1 ns / 1 ns

module nios_system_addr_router_001_default_decode
  #(
     parameter DEFAULT_CHANNEL = 1,
               DEFAULT_DESTID = 1 
   )
  (output [96 - 92 : 0] default_destination_id,
   output [22-1 : 0] default_src_channel
  );

  assign default_destination_id = 
    DEFAULT_DESTID[96 - 92 : 0];
  generate begin : default_decode
    if (DEFAULT_CHANNEL == -1)
      assign default_src_channel = '0;
    else
      assign default_src_channel = 22'b1 << DEFAULT_CHANNEL;
  end endgenerate

endmodule


module nios_system_addr_router_001
(
    // -------------------
    // Clock & Reset
    // -------------------
    input clk,
    input reset,

    // -------------------
    // Command Sink (Input)
    // -------------------
    input                       sink_valid,
    input  [107-1 : 0]    sink_data,
    input                       sink_startofpacket,
    input                       sink_endofpacket,
    output                      sink_ready,

    // -------------------
    // Command Source (Output)
    // -------------------
    output                          src_valid,
    output reg [107-1    : 0] src_data,
    output reg [22-1 : 0] src_channel,
    output                          src_startofpacket,
    output                          src_endofpacket,
    input                           src_ready
);

    // -------------------------------------------------------
    // Local parameters and variables
    // -------------------------------------------------------
    localparam PKT_ADDR_H = 67;
    localparam PKT_ADDR_L = 36;
    localparam PKT_DEST_ID_H = 96;
    localparam PKT_DEST_ID_L = 92;
    localparam ST_DATA_W = 107;
    localparam ST_CHANNEL_W = 22;
    localparam DECODER_TYPE = 0;

    localparam PKT_TRANS_WRITE = 70;
    localparam PKT_TRANS_READ  = 71;

    localparam PKT_ADDR_W = PKT_ADDR_H-PKT_ADDR_L + 1;
    localparam PKT_DEST_ID_W = PKT_DEST_ID_H-PKT_DEST_ID_L + 1;




    // -------------------------------------------------------
    // Figure out the number of bits to mask off for each slave span
    // during address decoding
    // -------------------------------------------------------
    localparam PAD0 = log2ceil(32'h800000 - 32'h0);
    localparam PAD1 = log2ceil(32'h8080000 - 32'h8000000);
    localparam PAD2 = log2ceil(32'h9002000 - 32'h9000000);
    localparam PAD3 = log2ceil(32'ha000800 - 32'ha000000);
    localparam PAD4 = log2ceil(32'h10000010 - 32'h10000000);
    localparam PAD5 = log2ceil(32'h10000020 - 32'h10000010);
    localparam PAD6 = log2ceil(32'h10000030 - 32'h10000020);
    localparam PAD7 = log2ceil(32'h10000040 - 32'h10000030);
    localparam PAD8 = log2ceil(32'h10000050 - 32'h10000040);
    localparam PAD9 = log2ceil(32'h10000060 - 32'h10000050);
    localparam PAD10 = log2ceil(32'h10000070 - 32'h10000060);
    localparam PAD11 = log2ceil(32'h10000080 - 32'h10000070);
    localparam PAD12 = log2ceil(32'h10000108 - 32'h10000100);
    localparam PAD13 = log2ceil(32'h10001008 - 32'h10001000);
    localparam PAD14 = log2ceil(32'h10001018 - 32'h10001010);
    localparam PAD15 = log2ceil(32'h10002020 - 32'h10002000);
    localparam PAD16 = log2ceil(32'h10002028 - 32'h10002020);
    localparam PAD17 = log2ceil(32'h10003010 - 32'h10003000);
    localparam PAD18 = log2ceil(32'h10003030 - 32'h10003020);
    localparam PAD19 = log2ceil(32'h10003038 - 32'h10003030);
    localparam PAD20 = log2ceil(32'h10003050 - 32'h10003040);
    localparam PAD21 = log2ceil(32'h10003052 - 32'h10003050);

    // -------------------------------------------------------
    // Work out which address bits are significant based on the
    // address range of the slaves. If the required width is too
    // large or too small, we use the address field width instead.
    // -------------------------------------------------------
    localparam ADDR_RANGE = 32'h10003052;
    localparam RANGE_ADDR_WIDTH = log2ceil(ADDR_RANGE);
    localparam OPTIMIZED_ADDR_H = (RANGE_ADDR_WIDTH > PKT_ADDR_W) ||
                                  (RANGE_ADDR_WIDTH == 0) ?
                                        PKT_ADDR_H :
                                        PKT_ADDR_L + RANGE_ADDR_WIDTH - 1;
    localparam RG = RANGE_ADDR_WIDTH-1;

      wire [PKT_ADDR_W-1 : 0] address = sink_data[OPTIMIZED_ADDR_H : PKT_ADDR_L];

    // -------------------------------------------------------
    // Pass almost everything through, untouched
    // -------------------------------------------------------
    assign sink_ready        = src_ready;
    assign src_valid         = sink_valid;
    assign src_startofpacket = sink_startofpacket;
    assign src_endofpacket   = sink_endofpacket;

    wire [PKT_DEST_ID_W-1:0] default_destid;
    wire [22-1 : 0] default_src_channel;




    nios_system_addr_router_001_default_decode the_default_decode(
      .default_destination_id (default_destid),
      .default_src_channel (default_src_channel)
    );

    always @* begin
        src_data    = sink_data;
        src_channel = default_src_channel;

        src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = default_destid;
        // --------------------------------------------------
        // Address Decoder
        // Sets the channel and destination ID based on the address
        // --------------------------------------------------

        // ( 0x0 .. 0x800000 )
        if ( {address[RG:PAD0],{PAD0{1'b0}}} == 'h0 ) begin
            src_channel = 22'b0000000000000000000010;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 1;
        end

        // ( 0x8000000 .. 0x8080000 )
        if ( {address[RG:PAD1],{PAD1{1'b0}}} == 'h8000000 ) begin
            src_channel = 22'b0000010000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 16;
        end

        // ( 0x9000000 .. 0x9002000 )
        if ( {address[RG:PAD2],{PAD2{1'b0}}} == 'h9000000 ) begin
            src_channel = 22'b0001000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 18;
        end

        // ( 0xa000000 .. 0xa000800 )
        if ( {address[RG:PAD3],{PAD3{1'b0}}} == 'ha000000 ) begin
            src_channel = 22'b0000000000000000000001;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 0;
        end

        // ( 0x10000000 .. 0x10000010 )
        if ( {address[RG:PAD4],{PAD4{1'b0}}} == 'h10000000 ) begin
            src_channel = 22'b0000000000000000100000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 5;
        end

        // ( 0x10000010 .. 0x10000020 )
        if ( {address[RG:PAD5],{PAD5{1'b0}}} == 'h10000010 ) begin
            src_channel = 22'b0000000000000001000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 6;
        end

        // ( 0x10000020 .. 0x10000030 )
        if ( {address[RG:PAD6],{PAD6{1'b0}}} == 'h10000020 ) begin
            src_channel = 22'b0000000000000010000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 7;
        end

        // ( 0x10000030 .. 0x10000040 )
        if ( {address[RG:PAD7],{PAD7{1'b0}}} == 'h10000030 ) begin
            src_channel = 22'b0000000000000100000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 8;
        end

        // ( 0x10000040 .. 0x10000050 )
        if ( {address[RG:PAD8],{PAD8{1'b0}}} == 'h10000040 ) begin
            src_channel = 22'b0000000000001000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 9;
        end

        // ( 0x10000050 .. 0x10000060 )
        if ( {address[RG:PAD9],{PAD9{1'b0}}} == 'h10000050 ) begin
            src_channel = 22'b0000000000010000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 10;
        end

        // ( 0x10000060 .. 0x10000070 )
        if ( {address[RG:PAD10],{PAD10{1'b0}}} == 'h10000060 ) begin
            src_channel = 22'b0000000000100000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 11;
        end

        // ( 0x10000070 .. 0x10000080 )
        if ( {address[RG:PAD11],{PAD11{1'b0}}} == 'h10000070 ) begin
            src_channel = 22'b0000000001000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 12;
        end

        // ( 0x10000100 .. 0x10000108 )
        if ( {address[RG:PAD12],{PAD12{1'b0}}} == 'h10000100 ) begin
            src_channel = 22'b0000001000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 15;
        end

        // ( 0x10001000 .. 0x10001008 )
        if ( {address[RG:PAD13],{PAD13{1'b0}}} == 'h10001000 ) begin
            src_channel = 22'b0000000000000000000100;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 2;
        end

        // ( 0x10001010 .. 0x10001018 )
        if ( {address[RG:PAD14],{PAD14{1'b0}}} == 'h10001010 ) begin
            src_channel = 22'b0000000010000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 13;
        end

        // ( 0x10002000 .. 0x10002020 )
        if ( {address[RG:PAD15],{PAD15{1'b0}}} == 'h10002000 ) begin
            src_channel = 22'b0000000000000000001000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 3;
        end

        // ( 0x10002020 .. 0x10002028 )
        if ( {address[RG:PAD16],{PAD16{1'b0}}} == 'h10002020 ) begin
            src_channel = 22'b0000000000000000010000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 4;
        end

        // ( 0x10003000 .. 0x10003010 )
        if ( {address[RG:PAD17],{PAD17{1'b0}}} == 'h10003000 ) begin
            src_channel = 22'b0010000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 19;
        end

        // ( 0x10003020 .. 0x10003030 )
        if ( {address[RG:PAD18],{PAD18{1'b0}}} == 'h10003020 ) begin
            src_channel = 22'b0100000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 20;
        end

        // ( 0x10003030 .. 0x10003038 )
        if ( {address[RG:PAD19],{PAD19{1'b0}}} == 'h10003030 ) begin
            src_channel = 22'b0000100000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 17;
        end

        // ( 0x10003040 .. 0x10003050 )
        if ( {address[RG:PAD20],{PAD20{1'b0}}} == 'h10003040 ) begin
            src_channel = 22'b1000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 21;
        end

        // ( 0x10003050 .. 0x10003052 )
        if ( {address[RG:PAD21],{PAD21{1'b0}}} == 'h10003050 ) begin
            src_channel = 22'b0000000100000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 14;
        end
    end

    // --------------------------------------------------
    // Ceil(log2()) function
    // --------------------------------------------------
    function integer log2ceil;
        input reg[63:0] val;
        reg [63:0] i;

        begin
            i = 1;
            log2ceil = 0;

            while (i < val) begin
                log2ceil = log2ceil + 1;
                i = i << 1;
            end
        end
    endfunction

endmodule


