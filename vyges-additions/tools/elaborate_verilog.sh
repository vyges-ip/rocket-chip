#!/usr/bin/env bash
# Elaborate rocket-chip (Chisel) → Verilog, reproducibly.
#
# rocket-chip is a Chisel generator: it has no checked-in Verilog top. This
# script performs the one-time Chisel→Verilog elaboration that produces the
# SystemVerilog for a chosen system top + config, so the generated RTL can be
# vendored / consumed by a downstream flow.
#
# Toolchain fetched by this script (no system install required): Mill + firtool.
# Host requirements: git, curl, tar, and a JDK (JDK 11 or 17 recommended;
# Scala 2.13 / Chisel 6.x target JDK <= 21).
#
# Usage:
#   ./elaborate_verilog.sh [OUT_DIR]
# Env overrides:
#   ROCKET_COMMIT  pin upstream commit (default: a known-good commit)
#   ROCKET_CONFIG  Chisel config class under freechips.rocketchip.system
#                  (default DefaultConfig = single big RV64GC core, Sv39 + FPU).
#                  NOTE: there is no 'DefaultRV64Config' — RV64 is the default.
#   ROCKET_TOP     system top to elaborate (default ExampleRocketSystem;
#                  do NOT use TestHarness — that wraps the SoC in sim glue).
#   CHISEL_XVER (6.7.0), MILL_VER (0.11.13), FIRTOOL_VER (1.62.1),
#   JAVA_HOME (point at a JDK 11/17 if the default java is too new)
set -euo pipefail

OUT_DIR="${1:-$PWD/rocket-elab-out}"
ROCKET_COMMIT="${ROCKET_COMMIT:-c1dda5827d214cf04a4d0917c1b2915e36603d52}"
ROCKET_CONFIG="${ROCKET_CONFIG:-DefaultConfig}"
ROCKET_TOP="${ROCKET_TOP:-ExampleRocketSystem}"
CHISEL_XVER="${CHISEL_XVER:-6.7.0}"
MILL_VER="${MILL_VER:-0.11.13}"
FIRTOOL_VER="${FIRTOOL_VER:-1.62.1}"   # Chisel 6.7-compatible; bump if FIR version mismatch.
UPSTREAM="https://github.com/chipsalliance/rocket-chip"

say() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }

say "Preflight"
command -v git  >/dev/null || { echo "ERROR: git required"; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl required"; exit 1; }
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"
"$JAVA" -version 2>&1 | head -1 || { echo "ERROR: java required (JDK 11/17)"; exit 1; }
case "$("$JAVA" -version 2>&1 | head -1)" in
  *\"1.8*|*\"11*|*\"17*|*\"21*) : ;;
  *) echo "WARN: Scala 2.13/Chisel 6.x target JDK<=21 — set JAVA_HOME to a JDK 11/17 if the build fails." ;;
esac

mkdir -p "$OUT_DIR"; cd "$OUT_DIR"

say "Clone rocket-chip @ $ROCKET_COMMIT (with submodules)"
if [ ! -d repo/.git ]; then
  git clone --recurse-submodules "$UPSTREAM" repo
  git -C repo checkout "$ROCKET_COMMIT"
  git -C repo submodule update --init --recursive
fi
RTL=repo
[ -f "$RTL/build.sc" ] || RTL=repo/rtl
[ -f "$RTL/build.sc" ] || { echo "ERROR: build.sc not found"; exit 1; }

say "Fetch Mill $MILL_VER launcher"
curl -fsSL "https://github.com/com-lihaoyi/mill/releases/download/$MILL_VER/$MILL_VER" -o "$RTL/mill"
chmod +x "$RTL/mill"

say "Build rocketchip assembly jar (mill) — first run downloads Chisel/Scala deps (~GB)"
( cd "$RTL" && ./mill "rocketchip[$CHISEL_XVER].assembly" )
JAR=$(find "$RTL/out/rocketchip/$CHISEL_XVER/assembly.dest" -name '*.jar' | head -1)
[ -n "$JAR" ] || { echo "ERROR: assembly jar not produced"; exit 1; }
JAR="$(cd "$(dirname "$JAR")" && pwd)/$(basename "$JAR")"

say "Elaborate $ROCKET_TOP / $ROCKET_CONFIG → FIRRTL"
# Run from the repo dir: the elaborator reads ./bootrom/bootrom.img relative to
# CWD, and --dir must already exist (the elaborator does not create it).
FIR_OUT="$OUT_DIR/fir"; mkdir -p "$FIR_OUT"
( cd "$RTL" && "$JAVA" -jar "$JAR" \
    --dir "$FIR_OUT" \
    --top "freechips.rocketchip.system.$ROCKET_TOP" \
    --config "freechips.rocketchip.system.$ROCKET_CONFIG" )
FIR=$(find "$FIR_OUT" -name '*.fir' | head -1)
ANNO=$(find "$FIR_OUT" -name '*.anno.json' | head -1)

say "Fetch firtool $FIRTOOL_VER + emit split Verilog"
# llvm/circt release asset is firrtl-bin-<platform>.tar.gz under the firtool-<ver> tag.
PLAT="linux-x64"; case "$(uname -s)-$(uname -m)" in Darwin-arm64) PLAT="macos-arm64";; Darwin-*) PLAT="macos-x64";; esac
curl -fL "https://github.com/llvm/circt/releases/download/firtool-$FIRTOOL_VER/firrtl-bin-$PLAT.tar.gz" -o firrtl-bin.tar.gz
tar xzf firrtl-bin.tar.gz
FIRTOOL=$(find . -maxdepth 3 -name firtool -type f -path '*bin*' | head -1)
chmod +x "$FIRTOOL"
VOUT="$OUT_DIR/verilog"; mkdir -p "$VOUT"
# firtool >= 1.62 has dedup on by default — the old `-dedup` flag was removed.
"$FIRTOOL" "$FIR" ${ANNO:+--annotation-file="$ANNO"} \
  --disable-annotation-unknown -O=debug \
  --preserve-values=named --split-verilog -o "$VOUT"

say "DONE"
echo "Verilog set: $VOUT ($(ls "$VOUT"/*.sv 2>/dev/null | wc -l | tr -d ' ') .sv files); file list: $VOUT/filelist.f"

# Copy the synthesizable Verilog blackboxes (vsrc) the elaborated design
# instantiates but firtool does NOT emit — they are hand-written upstream
# resources, not Chisel-generated: plusarg_reader (a +plusargs reader; under
# SYNTHESIS returns its DEFAULT), clock-gating / async-reset cells, clock
# dividers. SIM-only blackboxes (SimJTAG/SimDTM/TestDriver/emulator/
# RoccBlackBox/TraceSinkMonitor/debug_rob) are intentionally NOT copied.
# Without these the downstream SoC build fails Verilator/sv2v with MODMISSING.
VSRC_SRC="src/main/resources/vsrc"
for bb in plusarg_reader EICG_wrapper AsyncResetReg ClockDivider2 ClockDivider3; do
  [ -f "$VSRC_SRC/$bb.v" ] && cp "$VSRC_SRC/$bb.v" "$VOUT/$bb.v" && echo "  + vsrc blackbox $bb.v"
done
