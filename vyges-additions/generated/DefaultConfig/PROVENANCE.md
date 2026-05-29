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
