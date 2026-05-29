// @generated — vyges-soc-generator  DO NOT EDIT
// rocket_tile_tlul — TL-UL host wrapper around the elaborated Rocket SoC.
//   mmio_axi4 (AXI4 64b) -> axi_axil_adapter (AXIL 32b) -> tlul_axi_lite_bridge -> TL-UL host (tl_o/tl_i)
//   mem_axi4  -> exported m_axi_mem_* (to ZCU104 PS AXI-HP -> DDR)
//   Clock via 6 io_aggregator_*_clock members; reset (active-high) via *_reset members.
module rocket_tile_tlul import tlul_pkg::*; (
  input  logic clk_i,
  input  logic rst_ni,             // active-low; inverted to Rocket's active-high reset
  input  logic irq_external_i,     // PLIC claim line
  output tlul_pkg::tl_h2d_t tl_o,  // MMIO TL-UL host (-> xbar_main)
  input  tlul_pkg::tl_d2h_t tl_i,
  // Main-memory AXI4 master (-> board PS AXI-HP -> DDR)
  input  logic m_axi_mem_awready,
  output logic m_axi_mem_awvalid,
  output logic [3:0] m_axi_mem_awid,
  output logic [31:0] m_axi_mem_awaddr,
  output logic [7:0] m_axi_mem_awlen,
  output logic [2:0] m_axi_mem_awsize,
  output logic [1:0] m_axi_mem_awburst,
  output logic m_axi_mem_awlock,
  output logic [3:0] m_axi_mem_awcache,
  output logic [2:0] m_axi_mem_awprot,
  output logic [3:0] m_axi_mem_awqos,
  input  logic m_axi_mem_wready,
  output logic m_axi_mem_wvalid,
  output logic [63:0] m_axi_mem_wdata,
  output logic [7:0] m_axi_mem_wstrb,
  output logic m_axi_mem_wlast,
  output logic m_axi_mem_bready,
  input  logic m_axi_mem_bvalid,
  input  logic [3:0] m_axi_mem_bid,
  input  logic [1:0] m_axi_mem_bresp,
  input  logic m_axi_mem_arready,
  output logic m_axi_mem_arvalid,
  output logic [3:0] m_axi_mem_arid,
  output logic [31:0] m_axi_mem_araddr,
  output logic [7:0] m_axi_mem_arlen,
  output logic [2:0] m_axi_mem_arsize,
  output logic [1:0] m_axi_mem_arburst,
  output logic m_axi_mem_arlock,
  output logic [3:0] m_axi_mem_arcache,
  output logic [2:0] m_axi_mem_arprot,
  output logic [3:0] m_axi_mem_arqos,
  output logic m_axi_mem_rready,
  input  logic m_axi_mem_rvalid,
  input  logic [3:0] m_axi_mem_rid,
  input  logic [63:0] m_axi_mem_rdata,
  input  logic [1:0] m_axi_mem_rresp,
  input  logic m_axi_mem_rlast
);

  logic rst;  assign rst = ~rst_ni;   // Rocket clock-group resets are active-high

  // ── internal mmio AXI4 wires (Rocket mmio_axi4 <-> axi_axil_adapter.s_axi) ──
  logic mmio_aw_ready;
  logic mmio_aw_valid;
  logic [3:0] mmio_aw_bits_id;
  logic [30:0] mmio_aw_bits_addr;
  logic [7:0] mmio_aw_bits_len;
  logic [2:0] mmio_aw_bits_size;
  logic [1:0] mmio_aw_bits_burst;
  logic mmio_aw_bits_lock;
  logic [3:0] mmio_aw_bits_cache;
  logic [2:0] mmio_aw_bits_prot;
  logic [3:0] mmio_aw_bits_qos;
  logic mmio_w_ready;
  logic mmio_w_valid;
  logic [63:0] mmio_w_bits_data;
  logic [7:0] mmio_w_bits_strb;
  logic mmio_w_bits_last;
  logic mmio_b_ready;
  logic mmio_b_valid;
  logic [3:0] mmio_b_bits_id;
  logic [1:0] mmio_b_bits_resp;
  logic mmio_ar_ready;
  logic mmio_ar_valid;
  logic [3:0] mmio_ar_bits_id;
  logic [30:0] mmio_ar_bits_addr;
  logic [7:0] mmio_ar_bits_len;
  logic [2:0] mmio_ar_bits_size;
  logic [1:0] mmio_ar_bits_burst;
  logic mmio_ar_bits_lock;
  logic [3:0] mmio_ar_bits_cache;
  logic [2:0] mmio_ar_bits_prot;
  logic [3:0] mmio_ar_bits_qos;
  logic mmio_r_ready;
  logic mmio_r_valid;
  logic [3:0] mmio_r_bits_id;
  logic [63:0] mmio_r_bits_data;
  logic [1:0] mmio_r_bits_resp;
  logic mmio_r_bits_last;
  // ── AXI-Lite wires (adapter m_axil <-> tlul_axi_lite_bridge.s_axi) ──
  logic [30:0] axil_awaddr;
  logic [2:0] axil_awprot;
  logic axil_awvalid;
  logic axil_awready;
  logic [31:0] axil_wdata;
  logic [3:0] axil_wstrb;
  logic axil_wvalid;
  logic axil_wready;
  logic [1:0] axil_bresp;
  logic axil_bvalid;
  logic axil_bready;
  logic [30:0] axil_araddr;
  logic [2:0] axil_arprot;
  logic axil_arvalid;
  logic axil_arready;
  logic [31:0] axil_rdata;
  logic [1:0] axil_rresp;
  logic axil_rvalid;
  logic axil_rready;

  // ── Rocket SoC ──
  ExampleRocketSystem u_rocket (
    .io_aggregator_5_clock(clk_i),
    .io_aggregator_5_reset(rst),
    .io_aggregator_4_clock(clk_i),
    .io_aggregator_4_reset(rst),
    .io_aggregator_3_clock(clk_i),
    .io_aggregator_3_reset(rst),
    .io_aggregator_2_clock(clk_i),
    .io_aggregator_2_reset(rst),
    .io_aggregator_1_clock(clk_i),
    .io_aggregator_1_reset(rst),
    .io_aggregator_0_clock(clk_i),
    .io_aggregator_0_reset(rst),
    .resetctrl_hartIsInReset_0(1'b0),
    .debug_clock(clk_i),
    .debug_reset(rst),
    .debug_clockeddmi_dmi_req_ready(),
    .debug_clockeddmi_dmi_req_valid(1'b0),
    .debug_clockeddmi_dmi_req_bits_addr('0),
    .debug_clockeddmi_dmi_req_bits_data('0),
    .debug_clockeddmi_dmi_req_bits_op('0),
    .debug_clockeddmi_dmi_resp_ready(1'b0),
    .debug_clockeddmi_dmi_resp_valid(),
    .debug_clockeddmi_dmi_resp_bits_data(),
    .debug_clockeddmi_dmi_resp_bits_resp(),
    .debug_clockeddmi_dmiClock(clk_i),
    .debug_clockeddmi_dmiReset(rst),
    .debug_ndreset(),
    .debug_dmactive(),
    .debug_dmactiveAck(1'b0),
    .mem_axi4_0_aw_ready(m_axi_mem_awready),
    .mem_axi4_0_aw_valid(m_axi_mem_awvalid),
    .mem_axi4_0_aw_bits_id(m_axi_mem_awid),
    .mem_axi4_0_aw_bits_addr(m_axi_mem_awaddr),
    .mem_axi4_0_aw_bits_len(m_axi_mem_awlen),
    .mem_axi4_0_aw_bits_size(m_axi_mem_awsize),
    .mem_axi4_0_aw_bits_burst(m_axi_mem_awburst),
    .mem_axi4_0_aw_bits_lock(m_axi_mem_awlock),
    .mem_axi4_0_aw_bits_cache(m_axi_mem_awcache),
    .mem_axi4_0_aw_bits_prot(m_axi_mem_awprot),
    .mem_axi4_0_aw_bits_qos(m_axi_mem_awqos),
    .mem_axi4_0_w_ready(m_axi_mem_wready),
    .mem_axi4_0_w_valid(m_axi_mem_wvalid),
    .mem_axi4_0_w_bits_data(m_axi_mem_wdata),
    .mem_axi4_0_w_bits_strb(m_axi_mem_wstrb),
    .mem_axi4_0_w_bits_last(m_axi_mem_wlast),
    .mem_axi4_0_b_ready(m_axi_mem_bready),
    .mem_axi4_0_b_valid(m_axi_mem_bvalid),
    .mem_axi4_0_b_bits_id(m_axi_mem_bid),
    .mem_axi4_0_b_bits_resp(m_axi_mem_bresp),
    .mem_axi4_0_ar_ready(m_axi_mem_arready),
    .mem_axi4_0_ar_valid(m_axi_mem_arvalid),
    .mem_axi4_0_ar_bits_id(m_axi_mem_arid),
    .mem_axi4_0_ar_bits_addr(m_axi_mem_araddr),
    .mem_axi4_0_ar_bits_len(m_axi_mem_arlen),
    .mem_axi4_0_ar_bits_size(m_axi_mem_arsize),
    .mem_axi4_0_ar_bits_burst(m_axi_mem_arburst),
    .mem_axi4_0_ar_bits_lock(m_axi_mem_arlock),
    .mem_axi4_0_ar_bits_cache(m_axi_mem_arcache),
    .mem_axi4_0_ar_bits_prot(m_axi_mem_arprot),
    .mem_axi4_0_ar_bits_qos(m_axi_mem_arqos),
    .mem_axi4_0_r_ready(m_axi_mem_rready),
    .mem_axi4_0_r_valid(m_axi_mem_rvalid),
    .mem_axi4_0_r_bits_id(m_axi_mem_rid),
    .mem_axi4_0_r_bits_data(m_axi_mem_rdata),
    .mem_axi4_0_r_bits_resp(m_axi_mem_rresp),
    .mem_axi4_0_r_bits_last(m_axi_mem_rlast),
    .mmio_axi4_0_aw_ready(mmio_aw_ready),
    .mmio_axi4_0_aw_valid(mmio_aw_valid),
    .mmio_axi4_0_aw_bits_id(mmio_aw_bits_id),
    .mmio_axi4_0_aw_bits_addr(mmio_aw_bits_addr),
    .mmio_axi4_0_aw_bits_len(mmio_aw_bits_len),
    .mmio_axi4_0_aw_bits_size(mmio_aw_bits_size),
    .mmio_axi4_0_aw_bits_burst(mmio_aw_bits_burst),
    .mmio_axi4_0_aw_bits_lock(mmio_aw_bits_lock),
    .mmio_axi4_0_aw_bits_cache(mmio_aw_bits_cache),
    .mmio_axi4_0_aw_bits_prot(mmio_aw_bits_prot),
    .mmio_axi4_0_aw_bits_qos(mmio_aw_bits_qos),
    .mmio_axi4_0_w_ready(mmio_w_ready),
    .mmio_axi4_0_w_valid(mmio_w_valid),
    .mmio_axi4_0_w_bits_data(mmio_w_bits_data),
    .mmio_axi4_0_w_bits_strb(mmio_w_bits_strb),
    .mmio_axi4_0_w_bits_last(mmio_w_bits_last),
    .mmio_axi4_0_b_ready(mmio_b_ready),
    .mmio_axi4_0_b_valid(mmio_b_valid),
    .mmio_axi4_0_b_bits_id(mmio_b_bits_id),
    .mmio_axi4_0_b_bits_resp(mmio_b_bits_resp),
    .mmio_axi4_0_ar_ready(mmio_ar_ready),
    .mmio_axi4_0_ar_valid(mmio_ar_valid),
    .mmio_axi4_0_ar_bits_id(mmio_ar_bits_id),
    .mmio_axi4_0_ar_bits_addr(mmio_ar_bits_addr),
    .mmio_axi4_0_ar_bits_len(mmio_ar_bits_len),
    .mmio_axi4_0_ar_bits_size(mmio_ar_bits_size),
    .mmio_axi4_0_ar_bits_burst(mmio_ar_bits_burst),
    .mmio_axi4_0_ar_bits_lock(mmio_ar_bits_lock),
    .mmio_axi4_0_ar_bits_cache(mmio_ar_bits_cache),
    .mmio_axi4_0_ar_bits_prot(mmio_ar_bits_prot),
    .mmio_axi4_0_ar_bits_qos(mmio_ar_bits_qos),
    .mmio_axi4_0_r_ready(mmio_r_ready),
    .mmio_axi4_0_r_valid(mmio_r_valid),
    .mmio_axi4_0_r_bits_id(mmio_r_bits_id),
    .mmio_axi4_0_r_bits_data(mmio_r_bits_data),
    .mmio_axi4_0_r_bits_resp(mmio_r_bits_resp),
    .mmio_axi4_0_r_bits_last(mmio_r_bits_last),
    .l2_frontend_bus_axi4_0_aw_ready(),
    .l2_frontend_bus_axi4_0_aw_valid('0),
    .l2_frontend_bus_axi4_0_aw_bits_id('0),
    .l2_frontend_bus_axi4_0_aw_bits_addr('0),
    .l2_frontend_bus_axi4_0_aw_bits_len('0),
    .l2_frontend_bus_axi4_0_aw_bits_size('0),
    .l2_frontend_bus_axi4_0_aw_bits_burst('0),
    .l2_frontend_bus_axi4_0_aw_bits_lock('0),
    .l2_frontend_bus_axi4_0_aw_bits_cache('0),
    .l2_frontend_bus_axi4_0_aw_bits_prot('0),
    .l2_frontend_bus_axi4_0_aw_bits_qos('0),
    .l2_frontend_bus_axi4_0_w_ready(),
    .l2_frontend_bus_axi4_0_w_valid('0),
    .l2_frontend_bus_axi4_0_w_bits_data('0),
    .l2_frontend_bus_axi4_0_w_bits_strb('0),
    .l2_frontend_bus_axi4_0_w_bits_last('0),
    .l2_frontend_bus_axi4_0_b_ready('0),
    .l2_frontend_bus_axi4_0_b_valid(),
    .l2_frontend_bus_axi4_0_b_bits_id(),
    .l2_frontend_bus_axi4_0_b_bits_resp(),
    .l2_frontend_bus_axi4_0_ar_ready(),
    .l2_frontend_bus_axi4_0_ar_valid('0),
    .l2_frontend_bus_axi4_0_ar_bits_id('0),
    .l2_frontend_bus_axi4_0_ar_bits_addr('0),
    .l2_frontend_bus_axi4_0_ar_bits_len('0),
    .l2_frontend_bus_axi4_0_ar_bits_size('0),
    .l2_frontend_bus_axi4_0_ar_bits_burst('0),
    .l2_frontend_bus_axi4_0_ar_bits_lock('0),
    .l2_frontend_bus_axi4_0_ar_bits_cache('0),
    .l2_frontend_bus_axi4_0_ar_bits_prot('0),
    .l2_frontend_bus_axi4_0_ar_bits_qos('0),
    .l2_frontend_bus_axi4_0_r_ready('0),
    .l2_frontend_bus_axi4_0_r_valid(),
    .l2_frontend_bus_axi4_0_r_bits_id(),
    .l2_frontend_bus_axi4_0_r_bits_data(),
    .l2_frontend_bus_axi4_0_r_bits_resp(),
    .l2_frontend_bus_axi4_0_r_bits_last(),
    .interrupts({1'b0, irq_external_i})
  );

  // ── mmio: AXI4 (64b) -> AXI4-Lite (32b) ──
  axi_axil_adapter #(
    .ADDR_WIDTH(31), .AXI_DATA_WIDTH(64), .AXI_ID_WIDTH(4),
    .AXIL_DATA_WIDTH(32), .CONVERT_BURST(1), .CONVERT_NARROW_BURST(1)
  ) u_mmio_a2l (
    .clk(clk_i), .rst(rst),
    .s_axi_awid(mmio_aw_bits_id),
    .s_axi_awaddr(mmio_aw_bits_addr),
    .s_axi_awlen(mmio_aw_bits_len),
    .s_axi_awsize(mmio_aw_bits_size),
    .s_axi_awburst(mmio_aw_bits_burst),
    .s_axi_awlock(mmio_aw_bits_lock),
    .s_axi_awcache(mmio_aw_bits_cache),
    .s_axi_awprot(mmio_aw_bits_prot),
    .s_axi_awvalid(mmio_aw_valid),
    .s_axi_awready(mmio_aw_ready),
    .s_axi_wdata(mmio_w_bits_data),
    .s_axi_wstrb(mmio_w_bits_strb),
    .s_axi_wlast(mmio_w_bits_last),
    .s_axi_wvalid(mmio_w_valid),
    .s_axi_wready(mmio_w_ready),
    .s_axi_bid(mmio_b_bits_id),
    .s_axi_bresp(mmio_b_bits_resp),
    .s_axi_bvalid(mmio_b_valid),
    .s_axi_bready(mmio_b_ready),
    .s_axi_arid(mmio_ar_bits_id),
    .s_axi_araddr(mmio_ar_bits_addr),
    .s_axi_arlen(mmio_ar_bits_len),
    .s_axi_arsize(mmio_ar_bits_size),
    .s_axi_arburst(mmio_ar_bits_burst),
    .s_axi_arlock(mmio_ar_bits_lock),
    .s_axi_arcache(mmio_ar_bits_cache),
    .s_axi_arprot(mmio_ar_bits_prot),
    .s_axi_arvalid(mmio_ar_valid),
    .s_axi_arready(mmio_ar_ready),
    .s_axi_rid(mmio_r_bits_id),
    .s_axi_rdata(mmio_r_bits_data),
    .s_axi_rresp(mmio_r_bits_resp),
    .s_axi_rlast(mmio_r_bits_last),
    .s_axi_rvalid(mmio_r_valid),
    .s_axi_rready(mmio_r_ready),
    .m_axil_awaddr(axil_awaddr),
    .m_axil_awprot(axil_awprot),
    .m_axil_awvalid(axil_awvalid),
    .m_axil_awready(axil_awready),
    .m_axil_wdata(axil_wdata),
    .m_axil_wstrb(axil_wstrb),
    .m_axil_wvalid(axil_wvalid),
    .m_axil_wready(axil_wready),
    .m_axil_bresp(axil_bresp),
    .m_axil_bvalid(axil_bvalid),
    .m_axil_bready(axil_bready),
    .m_axil_araddr(axil_araddr),
    .m_axil_arprot(axil_arprot),
    .m_axil_arvalid(axil_arvalid),
    .m_axil_arready(axil_arready),
    .m_axil_rdata(axil_rdata),
    .m_axil_rresp(axil_rresp),
    .m_axil_rvalid(axil_rvalid),
    .m_axil_rready(axil_rready)
  );

  // ── mmio: AXI4-Lite -> TL-UL host ──
  tlul_axi_lite_bridge u_mmio_l2t (
    .s_axi_awaddr(axil_awaddr),
    .s_axi_awvalid(axil_awvalid),
    .s_axi_awready(axil_awready),
    .s_axi_wdata(axil_wdata),
    .s_axi_wstrb(axil_wstrb),
    .s_axi_wvalid(axil_wvalid),
    .s_axi_wready(axil_wready),
    .s_axi_bresp(axil_bresp),
    .s_axi_bvalid(axil_bvalid),
    .s_axi_bready(axil_bready),
    .s_axi_araddr(axil_araddr),
    .s_axi_arvalid(axil_arvalid),
    .s_axi_arready(axil_arready),
    .s_axi_rdata(axil_rdata),
    .s_axi_rresp(axil_rresp),
    .s_axi_rvalid(axil_rvalid),
    .s_axi_rready(axil_rready),
    .tl_o(tl_o), .tl_i(tl_i)
  );
endmodule
