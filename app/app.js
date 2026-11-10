const sodium = require('sodium-native')

const hash = Buffer.alloc(sodium.crypto_generichash_BYTES)
sodium.crypto_generichash(hash, Buffer.from('Hello from Bare'))

let count = 0

Bare.IPC.on('data', (data) => {
  count += data.byteLength

  const reply = { platform: Bare.platform, arch: Bare.arch, count, hash: hash.toString('hex') }

  Bare.IPC.write(JSON.stringify(reply) + '\n')
})
