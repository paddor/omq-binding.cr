# OMQ.rs binding for Crystal

Crystal binding for OMQ backed by `omq-libzmq`.

This is a thin Crystal FFI binding. `omq-libzmq` owns contexts, sockets,
transports, reconnects, routing, compression, and `inproc://`; Crystal code
owns only the public wrapper and Crystal object lifecycle.

![performance](https://raw.githubusercontent.com/paddor/omq-binding.cr/main/doc/charts/bindings.svg)

## Install

Requires Crystal 1.21 or newer and a Rust toolchain.

```yaml
dependencies:
  omq:
    github: paddor/omq-binding.cr
```

Shard install builds `libomq_zmq` automatically. Development and packaging
details: [`DEVELOPMENT.md`](DEVELOPMENT.md).

## Example

```crystal
require "omq"

ctx = OMQ.context
pull = ctx.socket("pull", linger: 0, recv_timeout: 1000)
push = ctx.socket("push", linger: 0, send_timeout: 1000)

endpoint = pull.bind("tcp://127.0.0.1:*")
push.connect(endpoint)
push.send("hello")
puts pull.recv

push.close
pull.close
ctx.term
```

PLAIN servers require an explicit policy. Pass fixed username/password pairs
through `plain_auth`:

```crystal
pull = ctx.socket(
  "pull",
  plain_auth: [{"alice", "secret"}, {"bob", "hunter2"}]
)
```

Clients use `Socket#set_plain_client`. PLAIN authenticates but does not encrypt
traffic. Bare `plain_server: true` uses standard ZAP and fails closed without a
ZAP handler.

## More

- Architecture and API coverage: [`doc/architecture.md`](doc/architecture.md)
- Development, tests, and benchmarks: [`DEVELOPMENT.md`](DEVELOPMENT.md)
