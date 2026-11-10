// The switch on a computer, on the DHT directly. Press enter to flip it.
//
//   node peer.js

const Session = require('bare-switch-core/session')

const session = new Session({
  onState: (on) => console.log('state -', on),
  onPeers: (count) => console.log('peers -', count)
})

console.log('up - key', session.publicKey, 'topic', Session.ROOM)

process.stdin.on('data', () => console.log('set -', session.setLocal(!session.on)))
