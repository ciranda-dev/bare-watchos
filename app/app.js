const Hyperswarm = require('hyperswarm')
const DHT = require('@hyperswarm/dht-relay')
const Stream = require('@ciranda/dht-relay-http')
const { URLSession, URLRequest } = require('bare-foundation')
const Session = require('bare-switch-core/session')
const HRPC = require('bare-switch-core/spec/hrpc')

const rpc = new HRPC(Bare.IPC)

let session = join()

rpc.onSetState(({ on }) => {
  console.log('[worklet] set -', on)
  return { on: session.setLocal(on) }
})

console.log('[worklet] up - key', session.publicKey, 'topic', Session.ROOM)
rpc.info({ publicKey: session.publicKey, topic: Session.ROOM })

// A watch gives an app no sockets, only URLSession, so the DHT is reached through a relay over
// HTTP. Never custodial: the keys stay here and the relay forwards only ciphertext. When the relay
// goes away, a new swarm joins through it again, with the same key and the same state.
function join(keyPair, on = false) {
  const relay = new Stream(Bare.argv[0], { fetch })
  const swarm = new Hyperswarm({ dht: new DHT(relay, { custodial: false }), keyPair })

  // The relayed DHT can connect to peers but not accept them, so the watch joins as a client.
  const joined = new Session({
    swarm,
    server: false,
    onState: (on) => {
      console.log('[worklet] state -', on)
      rpc.newState({ on })
    },
    onPeers: (count) => {
      console.log('[worklet] peers -', count)
      rpc.peersChanged({ count })
    }
  })

  joined.setLocal(on)

  relay
    .on('error', (err) => console.log('[worklet] relay -', err.message))
    .on('close', () => {
      swarm.destroy()
      setTimeout(() => {
        session = join(swarm.keyPair, joined.on)
      }, 5000)
    })

  return joined
}

function fetch(url, opts) {
  return new Promise((resolve, reject) => {
    const request = new URLRequest(url)

    request.httpMethod = opts.method

    for (const field in opts.headers) request.setValue(opts.headers[field], field)

    if (opts.body) request.httpBody = opts.body

    URLSession.shared
      .dataTask(request, (err, response, data) => {
        if (err) return reject(err)

        resolve({
          status: response.statusCode,
          arrayBuffer: () =>
            Promise.resolve(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength))
        })
      })
      .resume()
  })
}
