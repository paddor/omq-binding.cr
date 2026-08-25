# OMQ.cr Architecture

Crystal binding for `omq-libzmq`. The public shard lives in `src/omq.cr`.

Benchmark comparison uses separate OMQ and zeromq-crystal peer binaries. This
avoids linking `libomq_zmq` and system `libzmq` into one process, where
duplicate `zmq_*` symbols would invalidate the result.

## Source Layout

```text
src/omq.cr              public Crystal API and direct FFI declarations
spec/                   Crystal API, socket parity, option parity, and pyzmq
                        interop specs
scripts/bench_peer.cr   benchmark peer process
scripts/bench_peer_zeromq.cr
                        zeromq-crystal/libzmq benchmark peer process
scripts/update_perf.py  append-only bench runner and SVG chart generator
```

## Threading

Each socket follows the libzmq rule: one socket, one application thread.
`Socket#close` is idempotent. `Context#term` refuses to terminate while live
sockets exist, so sockets cannot keep calling into a terminated context.

`omq-libzmq` owns the OMQ context and IO threads. Crystal fibers do not own
transport, reconnect, ZMTP, compression, or routing state.

## Data Path

Send:

```text
Crystal Socket#send
  -> zmq_send
  -> omq-libzmq send path
  -> omq-tokio socket/routing/send pipe
  -> IO thread encodes and writes transport
```

Receive:

```text
IO thread reads and decodes transport
  -> omq-libzmq receive queue
  -> zmq_msg_recv / zmq_recv
  -> Crystal String allocation
```

Single-part messages up to OMQ's inline cutoff stay inline in OMQ message
storage. The Crystal binding still allocates a Crystal `String` for every
received frame.

## API Coverage

The binding is a thin wrapper over the `omq-libzmq` ABI. Crystal exports the
same socket, option, message, monitor, poll, mechanism, and draft constants as
`omq-libzmq/include/zmq.h`.

High-level wrappers cover contexts, sockets, generic socket options,
multipart messages, RADIO/DISH groups, poll, poller, proxy, CURVE, Z85,
monitor setup, and context share keys. Unsupported libzmq compatibility stubs
such as `DGRAM`, `zmq_connect_peer`, `zmq_socket_monitor_pipes_stats`, and
`zmq_socket_get_peer_state` are exposed and return the native `omq-libzmq`
error instead of being hidden by the Crystal layer.

## API Shape

- Socket constants: `PAIR`, `PUB`, `SUB`, `REQ`, `REP`, `DEALER`, `ROUTER`,
  `PULL`, `PUSH`, `XPUB`, `XSUB`, `STREAM`, `SERVER`, `CLIENT`, `RADIO`,
  `DISH`, `GATHER`, `SCATTER`, `DGRAM`, `PEER`, and `CHANNEL`.
- Flags and poll events: `DONTWAIT`, `NOBLOCK`, `SNDMORE`, `POLLIN`,
  `POLLOUT`, `POLLERR`, and `POLLPRI`.
- Context, socket option, monitor, message, mechanism, and draft constants
  match `omq-libzmq/include/zmq.h`.
- `OMQ::LibZMQ` declares the raw exported `zmq_*` and `omq_ctx_*` ABI for
  code that needs lower-level access.
- `OMQ.context(io_threads = 1)` creates a context.
- `OMQ.context_from_share_key(key)` imports a shared in-process OMQ context.
- `OMQ.version`, `OMQ.has(capability)`, `OMQ.curve_keypair`,
  `OMQ.curve_public(secret_key)`, `OMQ.z85_encode(bytes)`, and
  `OMQ.z85_decode(string)` expose libzmq utility APIs.
- `OMQ.poll(items, timeout_ms = -1)`, `OMQ::PollItem`, and `OMQ::Poller`
  expose `zmq_poll` and `zmq_poller_*`.
- `OMQ.proxy` and `OMQ.proxy_steerable` expose libzmq proxy helpers.
- `Context#socket("push", opts...)` creates a socket by name or numeric
  constant.
- Socket keyword options cover supported `omq-libzmq` options: linger,
  timeouts, HWM, identity/routing ID, reconnect, heartbeat, handshake,
  max message size, router options, TCP keepalive, buffers, XPUB flags,
  IPv6, immediate, PLAIN, CURVE, WSS, and `OMQ_ARENA_THRESHOLD`.
- `Context#term` closes the context. It errors while sockets are still live.
- `Context#close` aliases `#term`.
- `Context#set`, `Context#set_string`, `Context#set_bytes`, `Context#get`,
  `Context#get_ext_i32`, `Context#get_ext_string`, `Context#get_ext_bytes`,
  `Context#shutdown`, and `Context#share_key` expose native context APIs.
- `Socket#bind(endpoint)` binds and returns the resolved endpoint, including
  wildcard TCP ports when available.
- `Socket#connect(endpoint)` connects an endpoint.
- `Socket#unbind(endpoint)`, `Socket#disconnect(endpoint)`,
  `Socket#connect_peer(endpoint)`, and `Socket#disconnect_peer(routing_id)`
  expose endpoint lifecycle helpers.
- `Socket#join(group)`, `Socket#leave(group)`, and
  `Socket#send_group(group, payload)` support RADIO/DISH.
- `Socket#monitor`, `Socket#monitor_versioned`,
  `Socket#monitor_pipes_stats`, and `Socket#peer_state` expose monitor APIs.
- `Socket#close` closes the socket. It is idempotent.
- `Socket#send("bytes", flags = 0)` sends one frame.
- `Socket#send_const("bytes", flags = 0)` exposes `zmq_send_const`.
- `Socket#send_parts(["part1", "part2"], flags = 0)` sends multipart.
- `Socket#recv(max_size = nil, flags = 0)` receives one frame.
- `Socket#recv_into(buffer, flags = 0)` receives one frame into a caller-owned
  buffer and returns the byte count.
- `Socket#try_recv(max_size = nil)` is nonblocking and returns `nil` when no
  frame is ready.
- `Socket#try_recv_into(buffer)` is the nonblocking `Socket#recv_into` form.
- `Socket#recv_parts(max_size = nil, flags = 0)` receives all frames in one
  message.
- `Socket#subscribe(prefix)` and `Socket#unsubscribe(prefix)` manage SUB
  prefixes.
- `Socket#type`, `Socket#events`, `Socket#last_endpoint`,
  `Socket#get_option_i32`, `Socket#get_option_i64`,
  `Socket#get_option_string`, `Socket#get_option_bytes`, and matching
  `Socket#set_option_*` methods expose generic socket options.
