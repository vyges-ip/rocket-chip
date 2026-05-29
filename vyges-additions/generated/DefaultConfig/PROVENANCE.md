# Generated RTL — provenance

Pre-elaborated SystemVerilog for `ExampleRocketSystem` / `DefaultConfig`
(single big RV64GC core, Sv39 MMU + FPU). Committed so downstream flows consume
the RTL directly instead of re-running the Chisel elaboration.

| field | value |
|-------|-------|
| upstream | chipsalliance/rocket-chip |
| commit | c1dda5827d214cf04a4d0917c1b2915e36603d52 |
| system top | freechips.rocketchip.system.ExampleRocketSystem |
| config | freechips.rocketchip.system.DefaultConfig (RV64GC, Sv39, FPU) |
| Chisel | 6.7.0 (Scala 2.13.12) |
| firtool | 1.62.1 |
| generated | 2026-05-29T05:47:54Z |

External buses (see vyges-metadata.json interfaces):
- `mem_axi4`  — AXI4 master, 64-bit, base 0x8000_0000 → main memory (DDR)
- `mmio_axi4` — AXI4 master, base 0x6000_0000 → peripheral fabric
- `l2_frontend_bus_axi4` — AXI4 slave (external DMA into the cache)
- external interrupts → on-chip PLIC

Regenerate: `tools/elaborate_verilog.sh` (clones rocket-chip with submodules,
builds via Mill, elaborates, runs firtool --split-verilog).

## Clock & reset — READ before writing any host wrapper

ExampleRocketSystem has **no single bare `clock`/`reset` top port**. The clock
group is exposed as **six members** (one per on-chip clock domain — sbus, mbus,
pbus, fbus, cbus, etc.):

- `io_aggregator_0_clock` .. `io_aggregator_5_clock`
- `io_aggregator_0_reset` .. `io_aggregator_5_reset`  — **active-high**

plus debug pairs `debug_clock`/`debug_reset` and `debug_clockeddmi_dmiClock`/`dmiReset`.
`debug_ndreset` is an *output* (the debug-module ndmreset request), not a reset in.

**Single-clock FPGA wiring:** drive all six `io_aggregator_N_clock` (+ debug clocks)
from the system clock, and all six `io_aggregator_N_reset` (+ debug resets) from the
active-high system reset. Tie debug DMI (`*_req_valid`, `*_resp_ready`, `*_req_bits_*`),
`debug_dmactiveAck`, and `resetctrl_hartIsInReset_0` inactive when no debug module is used.
