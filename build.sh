#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p dist
cargo run -q --manifest-path ../8-bit_CPU_Programmer/assembler/Cargo.toml -- mos.asm --isa msap2 -f bin -o mos.bin -l mos.lst
cargo run -q --manifest-path ../8-bit_CPU_Programmer/assembler/Cargo.toml -- boot.asm --isa msap2 -f bin -o boot.bin -l boot.lst
node tools/packmos.mjs \
  mos.bin boot.bin dist/mos-runtime-8k.bin dist/MOS.BIN dist/factory-rom-8k.bin \
  ../MSAP-2/simulator/src/rom/mos-rom.json \
  ../MSAP-2/simulator/src/rom/factory-rom.json \
  ../MSAP-2/simulator/src/rom/mos-bin.json
cargo run -q --manifest-path ../8-bit_CPU_Programmer/assembler/Cargo.toml -- ed.asm --isa msap2 -f bin -o ed.bin -l ed.lst
node tools/bin2prog.mjs ed.bin ../MSAP-2/simulator/src/rom/ed-prog.json
cp mos.asm ed.asm ../8-bit_CPU_Programmer/assembler/tests/fixtures/
node ../MSAP-2/simulator/scripts/export-assembler-fixture.mjs \
  mos.asm ../8-bit_CPU_Programmer/assembler/tests/fixtures/mos.expected \
  ed.asm ../8-bit_CPU_Programmer/assembler/tests/fixtures/ed.expected
echo "MOS runtime, immutable factory ROM, MOS.BIN, and ED built; simulator images and fixtures updated"
