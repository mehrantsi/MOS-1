import { readFileSync, writeFileSync } from 'node:fs'
const [, , input, output] = process.argv
const bytes = readFileSync(input)
if (bytes.length > 0x1000) {
  console.error(`mos.bin is ${bytes.length} bytes - does not fit the 4KB ROM`)
  process.exit(1)
}
const rom = new Array(0x1000).fill(0)
bytes.forEach((b, i) => { rom[i] = b })
writeFileSync(output, JSON.stringify(rom))
console.log(`${input}: ${bytes.length} bytes -> ${output}`)
