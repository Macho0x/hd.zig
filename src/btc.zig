const std = @import("std");
const ripemd160 = @import("ripemd160.zig");
const ecmult_gen = @import("ecmult_gen.zig");

const HmacSha512 = std.crypto.auth.hmac.sha2.HmacSha512;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Secp256k1 = std.crypto.ecc.Secp256k1;

const HARDENED: u32 = 0x8000_0000;
const PATH_BIP84 = [_]u32{ 84 | HARDENED, 0 | HARDENED, HARDENED, 0, 0 };

const CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

pub const Error = error{
    IdentityElement,
    InvalidEncoding,
    NonCanonical,
    NotSquare,
};

pub fn mnemonicToSeed(phrase: []const u8) ![64]u8 {
    var seed: [64]u8 = undefined;
    try std.crypto.pwhash.pbkdf2(&seed, phrase, "mnemonic", 2048, HmacSha512);
    return seed;
}

fn hash160(compressed: *const [33]u8) [20]u8 {
    var sha: [32]u8 = undefined;
    Sha256.hash(compressed, &sha, .{});
    var out: [20]u8 = undefined;
    ripemd160.hash(&sha, &out);
    return out;
}

fn compressedPubkey(priv: *const [32]u8) Error![33]u8 {
    return ecmult_gen.mulG(priv) catch return error.IdentityElement;
}

fn derivePath(seed: *const [64]u8, path: []const u32) Error![32]u8 {
    var mac_out: [64]u8 = undefined;
    HmacSha512.create(&mac_out, seed, "Bitcoin seed");
    var priv = mac_out[0..32].*;
    var cc = mac_out[32..64].*;

    for (path) |index| {
        var data: [37]u8 = undefined;
        if (index >= HARDENED) {
            data[0] = 0;
            data[1..33].* = priv;
        } else {
            const pk = try compressedPubkey(&priv);
            data[0..33].* = pk;
        }
        std.mem.writeInt(u32, data[33..37], index, .big);
        HmacSha512.create(&mac_out, &data, &cc);
        const il = mac_out[0..32].*;
        cc = mac_out[32..64].*;
        priv = Secp256k1.scalar.add(il, priv, .big) catch return error.NonCanonical;
        if (std.mem.allEqual(u8, &priv, 0)) return error.IdentityElement;
    }
    return priv;
}

fn bech32Polymod(values: []const u8) u32 {
    const gen = [_]u32{ 0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3 };
    var chk: u32 = 1;
    for (values) |v| {
        const top = chk >> 25;
        chk = (chk & 0x1ffffff) << 5 ^ v;
        for (gen, 0..) |g, i| {
            if ((top >> @intCast(i)) & 1 == 1) chk ^= g;
        }
    }
    return chk;
}

/// BIP-84 native segwit P2WPKH (`bc1q…`), account 0 / index 0.
pub fn p2wpkh(seed: *const [64]u8) Error![42]u8 {
    const priv = try derivePath(seed, &PATH_BIP84);
    const pk = try compressedPubkey(&priv);
    const prog = hash160(&pk);

    var data5: [33]u8 = undefined;
    data5[0] = 0;
    var acc: u32 = 0;
    var bits: u32 = 0;
    var n: usize = 1;
    for (prog) |b| {
        acc = acc << 8 | b;
        bits += 8;
        while (bits >= 5) {
            bits -= 5;
            data5[n] = @truncate(acc >> @intCast(bits) & 31);
            n += 1;
        }
    }
    if (bits > 0) {
        data5[n] = @truncate(acc << @intCast(5 - bits) & 31);
        n += 1;
    }

    var values: [44]u8 = undefined;
    values[0] = 'b' >> 5;
    values[1] = 'c' >> 5;
    values[2] = 0;
    values[3] = 'b' & 31;
    values[4] = 'c' & 31;
    @memcpy(values[5 .. 5 + n], data5[0..n]);
    @memset(values[5 + n .. 5 + n + 6], 0);
    const pc = bech32Polymod(values[0 .. 5 + n + 6]) ^ 1;

    var out: [42]u8 = undefined;
    out[0] = 'b';
    out[1] = 'c';
    out[2] = '1';
    for (0..n) |i| out[3 + i] = CHARSET[data5[i]];
    for (0..6) |i| out[3 + n + i] = CHARSET[(pc >> @intCast(5 * (5 - i))) & 31];
    return out;
}

const ABANDON =
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

test "bip39 seed abandon" {
    const seed = try mnemonicToSeed(ABANDON);
    try std.testing.expectEqualStrings(
        "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4",
        &std.fmt.bytesToHex(seed, .lower),
    );
}

test "bip84 p2wpkh abandon" {
    const seed = try mnemonicToSeed(ABANDON);
    const addr = try p2wpkh(&seed);
    try std.testing.expectEqualStrings(
        "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
        &addr,
    );
}
