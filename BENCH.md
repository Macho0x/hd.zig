# Benchmarks

`zig build bench` (ReleaseFast). BIP-39 PBKDF2 runs once; the timed loop is address derivation only.

Host: Linux x86_64, Zig 0.16.0, 5000 rounds after one warmup call.

| Path | ns/op | µs/op |
|---|---:|---:|
| BTC BIP-84 P2WPKH `m/84'/0'/0'/0/0` | 363,330 | 363 |
| SOL SLIP-0010 `m/44'/501'/0'/0'` | 169,473 | 169 |

BTC is three `k·G` (two non-hardened CKD steps plus the address pubkey). The generator uses an 8-bit comb table and libsecp-style 5×52 `u128` field arithmetic in `src/field_5x52.zig` / `src/ecmult_gen.zig`. SOL is HMAC-SHA512 SLIP-0010 plus `std.crypto.sign.Ed25519`.

## Earlier revisions (same harness)

| Implementation | BTC ns/op | SOL ns/op |
|---|---:|---:|
| Zig std `Secp256k1.basePoint.mul` | 2,003,753 | 185,033 |
| OpenSSL `EC_POINT_mul` (C, then dropped) | 3,662,565 | 203,260 |
| Comb table + std field | 606,211 | 183,142 |
| Comb + 5×52 (current) | **363,330** | **169,473** |

Alloy.rs does not cover BIP-84 P2WPKH or SLIP-0010 Solana, so these are not compared to eth.zig’s alloy table.
