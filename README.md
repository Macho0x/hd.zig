# hd.zig

BIP-39 seed to chain addresses in Zig. Bitcoin BIP-84 P2WPKH (`bc1q…`) and Solana SLIP-0010 (`m/44'/501'/0'/0'`). Ethereum HD wallets stay in [eth.zig](https://github.com/StrobeLabs/eth.zig).

Zig >= 0.16.0. No C.

```zig
const hd = @import("hd");

const seed = try hd.mnemonicToSeed(
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
);
const btc = try hd.btcP2wpkh(&seed); // bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu
var buf: [44]u8 = undefined;
const sol = try hd.solAddress(&seed, &buf); // HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk
```

```bash
zig build test
zig build bench   # see [BENCH.md](BENCH.md)
```
