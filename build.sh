#!/bin/sh
set -e
cd "$(dirname "$0")"
cargo run -q --manifest-path ../8-bit_CPU_Programmer/assembler/Cargo.toml -- mos.asm --isa msap2 -f bin -o mos.bin -l mos.lst
node tools/bin2rom.mjs mos.bin ../MSAP-1/simulator-msap2/src/rom/mos-rom.json
cargo run -q --manifest-path ../8-bit_CPU_Programmer/assembler/Cargo.toml -- ed.asm --isa msap2 -f bin -o ed.bin -l ed.lst
node tools/bin2prog.mjs ed.bin ../MSAP-1/simulator-msap2/src/rom/ed-prog.json
cp mos.asm ed.asm ../8-bit_CPU_Programmer/assembler/tests/fixtures/
echo "MOS ROM + ED binary built; simulator images and fixtures updated"
