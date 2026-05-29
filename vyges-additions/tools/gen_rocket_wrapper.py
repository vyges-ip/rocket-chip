#!/usr/bin/env python3
"""Generate vyges-additions/rocket_tile_tlul.sv from the elaborated
ExampleRocketSystem port list. Connects all 141 ports by category:
  io_aggregator_N_clock → clk_i ; io_aggregator_N_reset → rst (active-high)
  debug clock/reset → clk_i/rst ; debug DMI + dmactiveAck + hartIsInReset → tied inactive
  interrupts → {pad, irq_external_i}
  mem_axi4_0_*  → top-level passthrough ports (to ZCU104 BD → PS AXI-HP → DDR)
  mmio_axi4_0_* → AXI4 (64b) → axi_axil_adapter (→AXIL 32b) → tlul_axi_lite_bridge → tl_o/tl_i
  l2_frontend_bus_axi4_0_* (slave) → inputs tied 0, outputs open
Usage: gen_rocket_wrapper.py ExampleRocketSystem.sv > rocket_tile_tlul.sv
"""
import re, sys

lines = open(sys.argv[1]).read().splitlines()
inmod = False; cur = None; ports = []
for ln in lines:
    if ln.startswith("module ExampleRocketSystem"): inmod = True; continue
    if not inmod: continue
    if re.match(r"^\s*\);", ln): break
    s = re.sub(r"//.*", "", ln).strip().rstrip(",").strip()
    m = re.match(r"^(input|output)\s+(.*)$", s)
    if m: cur = m.group(1); s = m.group(2).strip()
    if not s: continue
    wm = re.match(r"^(\[[0-9:]+\])\s+(.*)$", s)
    width, name = (wm.group(1), wm.group(2).strip()) if wm else ("", s)
    if name and cur: ports.append((cur, width, name))

def mem_top(name):  # mem_axi4_0_aw_bits_id -> m_axi_mem_awid (clean top port name)
    r = name[len("mem_axi4_0_"):]
    r = r.replace("_bits_", "_").replace("aw_", "aw").replace("ar_", "ar") \
         .replace("w_", "w").replace("b_", "b").replace("r_", "r")
    return "m_axi_mem_" + r

# ── build ExampleRocketSystem connections + collect mem top ports / mmio wires
conns = []; mem_ports = []; mmio_wires = []
for d, w, n in ports:
    if re.fullmatch(r"io_aggregator_\d+_clock", n) or n in ("debug_clock", "debug_clockeddmi_dmiClock"):
        net = "clk_i"
    elif re.fullmatch(r"io_aggregator_\d+_reset", n) or n in ("debug_reset", "debug_clockeddmi_dmiReset"):
        net = "rst"
    elif n == "interrupts":
        net = "{1'b0, irq_external_i}"
    elif n in ("resetctrl_hartIsInReset_0", "debug_dmactiveAck",
               "debug_clockeddmi_dmi_req_valid", "debug_clockeddmi_dmi_resp_ready"):
        net = "1'b0"
    elif n.startswith("debug_clockeddmi_dmi_req_bits"):
        net = "'0"
    elif n.startswith("mem_axi4_0_"):
        net = mem_top(n); mem_ports.append((d, w, net))
    elif n.startswith("mmio_axi4_0_"):
        net = "mmio_" + n[len("mmio_axi4_0_"):]; mmio_wires.append((d, w, net))
    elif n.startswith("l2_frontend_bus_axi4_0_"):
        net = "'0" if d == "input" else ""      # tie slave inputs, leave outputs open
    elif d == "output":
        net = ""                                 # unused outputs (debug_ndreset/dmactive/dmi_resp/req_ready) open
    else:
        net = "'0"                               # any stray input tied
    conns.append((n, net))

def decl(d, w, n):  # top-port declaration
    return f"  {'input ' if d=='input' else 'output'} logic {w + ' ' if w else ''}{n}"

P = []
P.append("// @generated — vyges-soc-generator  DO NOT EDIT")
P.append("// rocket_tile_tlul — TL-UL host wrapper around the elaborated Rocket SoC.")
P.append("//   mmio_axi4 (AXI4 64b) -> axi_axil_adapter (AXIL 32b) -> tlul_axi_lite_bridge -> TL-UL host (tl_o/tl_i)")
P.append("//   mem_axi4  -> exported m_axi_mem_* (to ZCU104 PS AXI-HP -> DDR)")
P.append("//   Clock via 6 io_aggregator_*_clock members; reset (active-high) via *_reset members.")
P.append("module rocket_tile_tlul import tlul_pkg::*; (")
P.append("  input  logic clk_i,")
P.append("  input  logic rst_ni,             // active-low; inverted to Rocket's active-high reset")
P.append("  input  logic irq_external_i,     // PLIC claim line")
P.append("  output tlul_pkg::tl_h2d_t tl_o,  // MMIO TL-UL host (-> xbar_main)")
P.append("  input  tlul_pkg::tl_d2h_t tl_i,")
P.append("  // Main-memory AXI4 master (-> board PS AXI-HP -> DDR)")
for d, w, n in mem_ports:
    P.append(decl(d, w, n) + ",")
P[-1] = P[-1].rstrip(",")
P.append(");")
P.append("")
P.append("  logic rst;  assign rst = ~rst_ni;   // Rocket clock-group resets are active-high")
P.append("")
P.append("  // ── internal mmio AXI4 wires (Rocket mmio_axi4 <-> axi_axil_adapter.s_axi) ──")
for d, w, n in mmio_wires:
    P.append(f"  logic {w + ' ' if w else ''}{n};")
P.append("  // ── AXI-Lite wires (adapter m_axil <-> tlul_axi_lite_bridge.s_axi) ──")
for nm, wd in [("awaddr","[30:0]"),("awprot","[2:0]"),("awvalid",""),("awready",""),
               ("wdata","[31:0]"),("wstrb","[3:0]"),("wvalid",""),("wready",""),
               ("bresp","[1:0]"),("bvalid",""),("bready",""),
               ("araddr","[30:0]"),("arprot","[2:0]"),("arvalid",""),("arready",""),
               ("rdata","[31:0]"),("rresp","[1:0]"),("rvalid",""),("rready","")]:
    P.append(f"  logic {wd + ' ' if wd else ''}axil_{nm};")
P.append("")
P.append("  // ── Rocket SoC ──")
P.append("  ExampleRocketSystem u_rocket (")
for n, net in conns:
    P.append(f"    .{n}({net}),")
P[-1] = P[-1].rstrip(",")
P.append("  );")
P.append("")

# ── AXI4 -> AXI4-Lite adapter (mmio): connect s_axi_* from mmio_* wires ──
# verilog-axi s_axi field -> Rocket mmio wire name (mmio_<chan>_<...>)
amap = {
 "awid":"aw_bits_id","awaddr":"aw_bits_addr","awlen":"aw_bits_len","awsize":"aw_bits_size",
 "awburst":"aw_bits_burst","awlock":"aw_bits_lock","awcache":"aw_bits_cache","awprot":"aw_bits_prot",
 "awvalid":"aw_valid","awready":"aw_ready",
 "wdata":"w_bits_data","wstrb":"w_bits_strb","wlast":"w_bits_last","wvalid":"w_valid","wready":"w_ready",
 "bid":"b_bits_id","bresp":"b_bits_resp","bvalid":"b_valid","bready":"b_ready",
 "arid":"ar_bits_id","araddr":"ar_bits_addr","arlen":"ar_bits_len","arsize":"ar_bits_size",
 "arburst":"ar_bits_burst","arlock":"ar_bits_lock","arcache":"ar_bits_cache","arprot":"ar_bits_prot",
 "arvalid":"ar_valid","arready":"ar_ready",
 "rid":"r_bits_id","rdata":"r_bits_data","rresp":"r_bits_resp","rlast":"r_bits_last",
 "rvalid":"r_valid","rready":"r_ready",
}
P.append("  // ── mmio: AXI4 (64b) -> AXI4-Lite (32b) ──")
P.append("  axi_axil_adapter #(")
P.append("    .ADDR_WIDTH(31), .AXI_DATA_WIDTH(64), .AXI_ID_WIDTH(4),")
P.append("    .AXIL_DATA_WIDTH(32), .CONVERT_BURST(1), .CONVERT_NARROW_BURST(1)")
P.append("  ) u_mmio_a2l (")
P.append("    .clk(clk_i), .rst(rst),")
for s, mmio in amap.items():
    P.append(f"    .s_axi_{s}(mmio_{mmio}),")
for nm in ["awaddr","awprot","awvalid","awready","wdata","wstrb","wvalid","wready",
           "bresp","bvalid","bready","araddr","arprot","arvalid","arready",
           "rdata","rresp","rvalid","rready"]:
    P.append(f"    .m_axil_{nm}(axil_{nm}),")
P[-1] = P[-1].rstrip(",")
P.append("  );")
P.append("")
P.append("  // ── mmio: AXI4-Lite -> TL-UL host ──")
P.append("  tlul_axi_lite_bridge u_mmio_l2t (")
for nm in ["awaddr","awvalid","awready","wdata","wstrb","wvalid","wready",
           "bresp","bvalid","bready","araddr","arvalid","arready",
           "rdata","rresp","rvalid","rready"]:
    P.append(f"    .s_axi_{nm}(axil_{nm}),")
P.append("    .tl_o(tl_o), .tl_i(tl_i)")
P.append("  );")
P.append("endmodule")
print("\n".join(P))
