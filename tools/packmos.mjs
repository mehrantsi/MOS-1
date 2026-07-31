import { createHash } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'

const [
  ,
  ,
  runtimeInput,
  bootInput,
  runtimeBinaryOutput,
  containerBinaryOutput,
  factoryBinaryOutput,
  runtimeJsonOutput,
  factoryJsonOutput,
  containerJsonOutput,
] = process.argv

if (!containerJsonOutput) {
  console.error(
    'usage: node tools/packmos.mjs runtime.bin boot.bin runtime-8k.bin MOS.BIN factory-8k.bin runtime.json factory.json container.json',
  )
  process.exit(1)
}

const imageSize = 0x2000
const bootStart = 0x1c00
const headerSize = 16
const runtimeSource = readFileSync(runtimeInput)
const bootSource = readFileSync(bootInput)

if (runtimeSource.length > bootStart) {
  throw new Error(
    `${runtimeInput} is ${runtimeSource.length} bytes; immutable fallback MOS must end before 0x${bootStart.toString(16).toUpperCase()}`,
  )
}
if (bootSource.length <= bootStart) {
  throw new Error(`${bootInput} has no emitted boot code at 0x${bootStart.toString(16).toUpperCase()}`)
}
if (bootSource.length > imageSize) {
  throw new Error(`${bootInput} is ${bootSource.length} bytes; boot code exceeds the 8 KiB ROM`)
}
if (bootSource.subarray(0, bootStart).some((byte) => byte !== 0)) {
  throw new Error(`${bootInput} emits bytes below the reserved boot region`)
}

const runtime = Buffer.alloc(imageSize)
runtimeSource.copy(runtime)
if (runtime[0] !== 0x30 || runtime[3] !== 0x30) {
  throw new Error('runtime image must contain JMP reset and fixed fallback vectors at 0x0000 and 0x0003')
}
if (!runtime.subarray(0, 3).equals(runtime.subarray(3, 6))) {
  throw new Error('fixed fallback vector at 0x0003 must enter the same cold-start MOS path as the runtime reset vector')
}
if (runtime[1] === 0x00 && runtime[2] === 0x1c) {
  throw new Error('runtime reset vector must enter MOS, not the immutable bootloader')
}

let sum1 = 0
let sum2 = 0
for (const byte of runtime) {
  sum1 = (sum1 + byte) % 255
  sum2 = (sum2 + sum1) % 255
}

const header = Buffer.from([
  0x4d, 0x32, 0x4f, 0x53,
  1, headerSize,
  0, 0,
  0, 0x20,
  0, 0,
  sum1, sum2,
  0, 0,
])
const container = Buffer.concat([header, runtime])
if (container.length !== headerSize + imageSize) {
  throw new Error(`MOS.BIN must be exactly ${headerSize + imageSize} bytes`)
}

const factory = Buffer.from(runtime)
bootSource.subarray(bootStart).copy(factory, bootStart)
factory[0] = 0x30
factory[1] = bootStart & 0xff
factory[2] = bootStart >> 8
if (factory[0] !== 0x30 || factory[1] !== 0x00 || factory[2] !== 0x1c) {
  throw new Error('factory reset vector does not enter the immutable bootloader')
}
if (!factory.subarray(3, bootStart).equals(runtime.subarray(3, bootStart))) {
  throw new Error('factory image changed the immutable fallback MOS')
}

const writeJson = (path, bytes) => writeFileSync(path, JSON.stringify(Array.from(bytes)))
writeFileSync(runtimeBinaryOutput, runtime)
writeFileSync(containerBinaryOutput, container)
writeFileSync(factoryBinaryOutput, factory)
writeJson(runtimeJsonOutput, runtime)
writeJson(factoryJsonOutput, factory)
writeJson(containerJsonOutput, container)

const digest = (bytes) => createHash('sha256').update(bytes).digest('hex')
console.log(`runtime  ${runtime.length} bytes  sha256 ${digest(runtime)}`)
console.log(`MOS.BIN  ${container.length} bytes  Fletcher ${sum1.toString(16).padStart(2, '0')}${sum2.toString(16).padStart(2, '0')}  sha256 ${digest(container)}`)
console.log(`factory  ${factory.length} bytes  boot 0x${bootStart.toString(16).toUpperCase()}-0x${(bootSource.length - 1).toString(16).toUpperCase()}  sha256 ${digest(factory)}`)
