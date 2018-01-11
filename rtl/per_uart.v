/*
 * Copyright (c) 2017-2018, Alex Taradov <alex@taradov.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

`timescale 1ns / 1ps

module per_uart (
  input         clk_i,
  input         reset_i,

  input  [15:0] addr_i,
  input  [31:0] wdata_i,
  output [31:0] rdata_o,
  input   [1:0] size_i,
  input         rd_i,
  input         wr_i,

  input         uart_rx_i,
  output        uart_tx_o
);


//-----------------------------------------------------------------------------
localparam
  REG_CSR  = 16'h0000,
  REG_DATA = 16'h0004;
  
  // TODO: baudrate register
`define BAUDRATE_DIV   434 // 115200

localparam
  BIT_CSR_TX_READY  = 0,
  BIT_CSR_RX_READY  = 1;

//-----------------------------------------------------------------------------
`ifdef SIMULATOR
always @(posedge clk_i) begin
  if (wr_i && (REG_DATA == addr_i))
    $write("%c", wdata_i[7:0]);
end

assign uart_tx_o = 1'b1;

`else
//-----------------------------------------------------------------------------
reg [9:0] br_cnt_r;
reg [3:0] bit_cnt_r;
reg [9:0] shifter_r;
reg       tx_ready_r;

always @(posedge clk_i) begin
  if (reset_i) begin
    br_cnt_r   <= 10'd0;
    bit_cnt_r  <= 4'd0;
    shifter_r  <= 10'h1;
    tx_ready_r <= 1'b1;
  end else if (bit_cnt_r) begin
    if (`BAUDRATE_DIV == br_cnt_r) begin
      shifter_r <= { 1'b1, shifter_r[9:1] };
      bit_cnt_r <= bit_cnt_r - 4'd1;
      br_cnt_r  <= 10'd0;
    end else begin
      br_cnt_r  <= br_cnt_r + 10'd1;
    end
  end else if (!tx_ready_r) begin
    tx_ready_r <= 1'b1;
  end else if (wr_i && (REG_DATA == addr_i)) begin
    shifter_r  <= { 1'b1, wdata_i[7:0], 1'b0 };
    bit_cnt_r  <= 4'd10;
    tx_ready_r <= 1'b0;
  end
end

assign uart_tx_o = shifter_r[0];
`endif

//-----------------------------------------------------------------------------
reg [31:0] reg_data_r;

always @(posedge clk_i) begin
  reg_data_r <= csr_w;
end

//-----------------------------------------------------------------------------
wire [31:0] csr_w;

`ifdef SIMULATOR
assign csr_w[BIT_CSR_TX_READY] = 1'b1;
assign csr_w[BIT_CSR_RX_READY] = 1'b0;
`else
assign csr_w[BIT_CSR_TX_READY] = tx_ready_r;
assign csr_w[BIT_CSR_RX_READY] = 1'b0; // TODO: TX only for now
`endif

assign csr_w[31:2] = 30'h0;

//-----------------------------------------------------------------------------
assign rdata_o = reg_data_r;

endmodule
