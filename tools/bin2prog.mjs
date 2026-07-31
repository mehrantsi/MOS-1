import { readFileSync, writeFileSync } from 'node:fs'
const [, , input, output] = process.argv
const bytes = readFileSync(input)
const skip = 0x2000
if (bytes.length <= skip) {
  console.error(`${input} has no bytes above 0x2000`)
  process.exit(1)
}
writeFileSync(output, JSON.stringify(Array.from(bytes.slice(skip))))
console.log(`${input}: ${bytes.length - skip} program bytes -> ${output}`)
