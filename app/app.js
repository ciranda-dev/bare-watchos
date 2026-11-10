const Hyperswarm = require('hyperswarm')
const DHT = require('@hyperswarm/dht-relay')
const Stream = require('@ciranda/dht-relay-http')
const { URLSession, URLRequest } = require('bare-foundation')
const Session = require('bare-switch-core/session')
const HRPC = require('bare-switch-core/spec/hrpc')

// A watch gives an app no sockets, only URLSession, so the DHT is reached through a relay over
// HTTP. Never custodial: the keys stay here and the relay forwards only ciphertext.
const relay = new Stream(Bare.argv[0], { fetch })

// Without the relay the switch has no peers until the app starts again.
relay.on('error', (err) => console.log('[worklet] relay -', err.message))

const dht = new DHT(relay, { custodial: false })

const rpc = new HRPC(Bare.IPC)

// The relayed DHT can connect to peers but not accept them, so the watch joins as a client.
const session = new Session({
  swarm: new Hyperswarm({ dht }),
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

rpc.onSetState(({ on }) => {
  console.log('[worklet] set -', on)
  return { on: session.setLocal(on) }
})

console.log('[worklet] up - key', session.publicKey, 'topic', Session.ROOM)
rpc.info({ publicKey: session.publicKey, topic: Session.ROOM })

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
