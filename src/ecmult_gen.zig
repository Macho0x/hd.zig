const std = @import("std");
const Secp256k1 = std.crypto.ecc.Secp256k1;
const Fe52 = @import("field_5x52.zig").Fe;
const StdFe = Secp256k1.Fe;
const AffineStd = @TypeOf(Secp256k1.basePoint.affineCoordinates());

const BLOCKS = 32;
const TEETH = 255;

const Affine = struct { x: Fe52, y: Fe52 };
const Jac = struct { x: Fe52, y: Fe52, z: Fe52 };

var prec: [BLOCKS][TEETH]Affine = undefined;
var ready: bool = false;

fn dbl8(p: Secp256k1) Secp256k1 {
    var q = p;
    inline for (0..8) |_| q = q.dbl();
    return q;
}

fn batchAffine(jac: *const [TEETH]Secp256k1, out: *[TEETH]AffineStd) void {
    var prod: [TEETH]StdFe = undefined;
    prod[0] = jac[0].z;
    for (1..TEETH) |i| prod[i] = prod[i - 1].mul(jac[i].z);
    var inv = prod[TEETH - 1].invert();
    var i: usize = TEETH;
    while (i > 0) {
        i -= 1;
        const zinv = if (i == 0) inv else inv.mul(prod[i - 1]);
        if (i > 0) inv = inv.mul(jac[i].z);
        out[i] = .{ .x = jac[i].x.mul(zinv), .y = jac[i].y.mul(zinv) };
    }
}

fn to52(p: AffineStd) Affine {
    return .{
        .x = Fe52.fromB32(&p.x.toBytes(.big)),
        .y = Fe52.fromB32(&p.y.toBytes(.big)),
    };
}

fn fill() void {
    if (ready) return;
    var g = Secp256k1.basePoint;
    var jac: [TEETH]Secp256k1 = undefined;
    var tmp: [TEETH]AffineStd = undefined;
    for (0..BLOCKS) |j| {
        var p = g;
        for (0..TEETH) |i| {
            jac[i] = p;
            p = p.add(g);
        }
        batchAffine(&jac, &tmp);
        for (0..TEETH) |i| prec[j][i] = to52(tmp[i]);
        g = dbl8(g);
    }
    ready = true;
}

fn addMixed(a: Jac, b: Affine) Jac {
    const z1z1 = a.z.sq();
    const xx = b.x.mul(z1z1);
    const yy = b.y.mul(z1z1.mul(a.z));
    const h = xx.sub(a.x);
    const r = yy.sub(a.y);
    const hh = h.sq();
    const hhh = h.mul(hh);
    const v = a.x.mul(hh);
    const x3 = r.sq().sub(hhh).sub(v.dbl());
    const y3 = r.mul(v.sub(x3)).sub(a.y.mul(hhh));
    return .{ .x = x3, .y = y3, .z = a.z.mul(h) };
}

fn inv52(a: Fe52) Fe52 {
    const z = StdFe.fromBytes(a.normalize().toB32(), .big) catch unreachable;
    return Fe52.fromB32(&z.invert().toBytes(.big));
}

/// k·G, variable-time. `k` is a big-endian scalar. Returns compressed SEC1.
pub fn mulG(k: *const [32]u8) ![33]u8 {
    fill();
    var q: Jac = undefined;
    var started = false;
    for (0..BLOCKS) |j| {
        const n = k[31 - j];
        if (n == 0) continue;
        const pt = prec[j][n - 1];
        if (!started) {
            q = .{ .x = pt.x, .y = pt.y, .z = Fe52.one };
            started = true;
        } else {
            q = addMixed(q, pt);
        }
    }
    if (!started) return error.IdentityElement;
    const zi = inv52(q.z);
    const zi2 = zi.sq();
    const x = q.x.mul(zi2).normalize();
    const y = q.y.mul(zi2.mul(zi)).normalize();
    var out: [33]u8 = undefined;
    out[0] = if (y.isOdd()) 3 else 2;
    out[1..].* = x.toB32();
    return out;
}

test "5x52 mul matches std field" {
    const a = try StdFe.fromInt(123456789);
    const b = try StdFe.fromInt(987654321);
    const want = a.mul(b).toBytes(.big);
    const got = Fe52.fromB32(&a.toBytes(.big)).mul(Fe52.fromB32(&b.toBytes(.big))).normalize().toB32();
    try std.testing.expectEqual(want, got);
}

test "mulG matches std basePoint.mul" {
    const k1 = [_]u8{0} ** 31 ++ [_]u8{7};
    try std.testing.expectEqual(
        (try Secp256k1.basePoint.mul(k1, .big)).toCompressedSec1(),
        try mulG(&k1),
    );
    var k256 = [_]u8{0} ** 32;
    k256[30] = 1;
    try std.testing.expectEqual(
        (try Secp256k1.basePoint.mul(k256, .big)).toCompressedSec1(),
        try mulG(&k256),
    );
    var k257 = k256;
    k257[31] = 1;
    try std.testing.expectEqual(
        (try Secp256k1.basePoint.mul(k257, .big)).toCompressedSec1(),
        try mulG(&k257),
    );
}
