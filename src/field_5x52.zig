//! 5×52 field arithmetic after libsecp256k1 (MIT, Pieter Wuille).
//! Limbs are base 2^52; `p = 2^256 - 2^32 - 977`.

const M: u64 = 0xFFFFFFFFFFFFF;
const R: u64 = 0x1000003D10;

pub const Fe = struct {
    n: [5]u64 = .{ 0, 0, 0, 0, 0 },

    pub const one: Fe = .{ .n = .{ 1, 0, 0, 0, 0 } };

    pub fn fromB32(a: *const [32]u8) Fe {
        return .{ .n = .{
            @as(u64, a[31]) |
                @as(u64, a[30]) << 8 |
                @as(u64, a[29]) << 16 |
                @as(u64, a[28]) << 24 |
                @as(u64, a[27]) << 32 |
                @as(u64, a[26]) << 40 |
                @as(u64, a[25] & 0xF) << 48,
            @as(u64, a[25] >> 4) |
                @as(u64, a[24]) << 4 |
                @as(u64, a[23]) << 12 |
                @as(u64, a[22]) << 20 |
                @as(u64, a[21]) << 28 |
                @as(u64, a[20]) << 36 |
                @as(u64, a[19]) << 44,
            @as(u64, a[18]) |
                @as(u64, a[17]) << 8 |
                @as(u64, a[16]) << 16 |
                @as(u64, a[15]) << 24 |
                @as(u64, a[14]) << 32 |
                @as(u64, a[13]) << 40 |
                @as(u64, a[12] & 0xF) << 48,
            @as(u64, a[12] >> 4) |
                @as(u64, a[11]) << 4 |
                @as(u64, a[10]) << 12 |
                @as(u64, a[9]) << 20 |
                @as(u64, a[8]) << 28 |
                @as(u64, a[7]) << 36 |
                @as(u64, a[6]) << 44,
            @as(u64, a[5]) |
                @as(u64, a[4]) << 8 |
                @as(u64, a[3]) << 16 |
                @as(u64, a[2]) << 24 |
                @as(u64, a[1]) << 32 |
                @as(u64, a[0]) << 40,
        } };
    }

    pub fn toB32(a: Fe) [32]u8 {
        const n = a.n;
        return .{
            @truncate(n[4] >> 40), @truncate(n[4] >> 32), @truncate(n[4] >> 24),
            @truncate(n[4] >> 16), @truncate(n[4] >> 8),  @truncate(n[4]),
            @truncate(n[3] >> 44), @truncate(n[3] >> 36), @truncate(n[3] >> 28),
            @truncate(n[3] >> 20), @truncate(n[3] >> 12), @truncate(n[3] >> 4),
            @truncate((n[2] >> 48) | (n[3] << 4)),
            @truncate(n[2] >> 40), @truncate(n[2] >> 32), @truncate(n[2] >> 24),
            @truncate(n[2] >> 16), @truncate(n[2] >> 8),  @truncate(n[2]),
            @truncate(n[1] >> 44), @truncate(n[1] >> 36), @truncate(n[1] >> 28),
            @truncate(n[1] >> 20), @truncate(n[1] >> 12), @truncate(n[1] >> 4),
            @truncate((n[0] >> 48) | (n[1] << 4)),
            @truncate(n[0] >> 40), @truncate(n[0] >> 32), @truncate(n[0] >> 24),
            @truncate(n[0] >> 16), @truncate(n[0] >> 8),  @truncate(n[0]),
        };
    }

    pub fn add(a: Fe, b: Fe) Fe {
        return (Fe{ .n = .{
            a.n[0] +% b.n[0],
            a.n[1] +% b.n[1],
            a.n[2] +% b.n[2],
            a.n[3] +% b.n[3],
            a.n[4] +% b.n[4],
        } }).normalizeWeak();
    }

    pub fn dbl(a: Fe) Fe {
        return a.add(a);
    }

    pub fn neg1(a: Fe) Fe {
        const k: u64 = 4;
        return (Fe{ .n = .{
            0xFFFFEFFFFFC2F * k -% a.n[0],
            M * k -% a.n[1],
            M * k -% a.n[2],
            M * k -% a.n[3],
            0x0FFFFFFFFFFFF * k -% a.n[4],
        } }).normalizeWeak();
    }

    pub fn sub(a: Fe, b: Fe) Fe {
        return a.add(b.neg1());
    }

    pub fn mul(a: Fe, b: Fe) Fe {
        var r: [5]u64 = undefined;
        mulInner(&r, &a.normalizeWeak().n, &b.normalizeWeak().n);
        return .{ .n = r };
    }

    pub fn sq(a: Fe) Fe {
        var r: [5]u64 = undefined;
        sqrInner(&r, &a.normalizeWeak().n);
        return .{ .n = r };
    }

    pub fn isOdd(a: Fe) bool {
        return a.n[0] & 1 == 1;
    }

    pub fn normalize(a: Fe) Fe {
        var t0, var t1, var t2, var t3, var t4 = .{ a.n[0], a.n[1], a.n[2], a.n[3], a.n[4] };
        var x = t4 >> 48;
        t4 &= 0x0FFFFFFFFFFFF;
        t0 += x *% 0x1000003D1;
        t1 += t0 >> 52;
        t0 &= M;
        t2 += t1 >> 52;
        t1 &= M;
        var mm = t1;
        t3 += t2 >> 52;
        t2 &= M;
        mm &= t2;
        t4 += t3 >> 52;
        t3 &= M;
        mm &= t3;
        x = (t4 >> 48) | @intFromBool((t4 == 0x0FFFFFFFFFFFF) and (mm == M) and (t0 >= 0xFFFFEFFFFFC2F));
        if (x != 0) {
            t0 += 0x1000003D1;
            t1 += t0 >> 52;
            t0 &= M;
            t2 += t1 >> 52;
            t1 &= M;
            t3 += t2 >> 52;
            t2 &= M;
            t4 += t3 >> 52;
            t3 &= M;
            t4 &= 0x0FFFFFFFFFFFF;
        }
        return .{ .n = .{ t0, t1, t2, t3, t4 } };
    }

    fn normalizeWeak(a: Fe) Fe {
        var t0, var t1, var t2, var t3, var t4 = .{ a.n[0], a.n[1], a.n[2], a.n[3], a.n[4] };
        const x = t4 >> 48;
        t4 &= 0x0FFFFFFFFFFFF;
        t0 += x *% 0x1000003D1;
        t1 += t0 >> 52;
        t0 &= M;
        t2 += t1 >> 52;
        t1 &= M;
        t3 += t2 >> 52;
        t2 &= M;
        t4 += t3 >> 52;
        t3 &= M;
        return .{ .n = .{ t0, t1, t2, t3, t4 } };
    }
};

inline fn accum(d: *u128, x: u64, y: u64) void {
    d.* += @as(u128, x) * @as(u128, y);
}

fn mulInner(r: *[5]u64, a: *const [5]u64, b: *const [5]u64) void {
    const a0, const a1, const a2, const a3, const a4 = .{ a[0], a[1], a[2], a[3], a[4] };
    var d: u128 = 0;
    accum(&d, a0, b[3]);
    accum(&d, a1, b[2]);
    accum(&d, a2, b[1]);
    accum(&d, a3, b[0]);
    var c: u128 = @as(u128, a4) * @as(u128, b[4]);
    accum(&d, R, @truncate(c));
    c >>= 64;
    const t3: u64 = @as(u64, @truncate(d)) & M;
    d >>= 52;

    accum(&d, a0, b[4]);
    accum(&d, a1, b[3]);
    accum(&d, a2, b[2]);
    accum(&d, a3, b[1]);
    accum(&d, a4, b[0]);
    accum(&d, R << 12, @truncate(c));
    var t4: u64 = @as(u64, @truncate(d)) & M;
    d >>= 52;
    const tx: u64 = t4 >> 48;
    t4 &= M >> 4;

    c = @as(u128, a0) * @as(u128, b[0]);
    accum(&d, a1, b[4]);
    accum(&d, a2, b[3]);
    accum(&d, a3, b[2]);
    accum(&d, a4, b[1]);
    var w: u64 = @as(u64, @truncate(d)) & M;
    d >>= 52;
    w = (w << 4) | tx;
    accum(&c, w, R >> 4);
    r[0] = @as(u64, @truncate(c)) & M;
    c >>= 52;

    accum(&c, a0, b[1]);
    accum(&c, a1, b[0]);
    accum(&d, a2, b[4]);
    accum(&d, a3, b[3]);
    accum(&d, a4, b[2]);
    accum(&c, @as(u64, @truncate(d)) & M, R);
    d >>= 52;
    r[1] = @as(u64, @truncate(c)) & M;
    c >>= 52;

    accum(&c, a0, b[2]);
    accum(&c, a1, b[1]);
    accum(&c, a2, b[0]);
    accum(&d, a3, b[4]);
    accum(&d, a4, b[3]);
    accum(&c, R, @truncate(d));
    d >>= 64;
    r[2] = @as(u64, @truncate(c)) & M;
    c >>= 52;
    accum(&c, R << 12, @truncate(d));
    c += t3;
    r[3] = @as(u64, @truncate(c)) & M;
    c >>= 52;
    r[4] = @as(u64, @truncate(c)) +% t4;
}

fn sqrInner(r: *[5]u64, a: *const [5]u64) void {
    var a0, const a1, const a2, const a3, var a4 = .{ a[0], a[1], a[2], a[3], a[4] };
    var d: u128 = 0;
    accum(&d, a0 *% 2, a3);
    accum(&d, a1 *% 2, a2);
    var c: u128 = @as(u128, a4) * @as(u128, a4);
    accum(&d, R, @truncate(c));
    c >>= 64;
    const t3: u64 = @as(u64, @truncate(d)) & M;
    d >>= 52;

    a4 *%= 2;
    accum(&d, a0, a4);
    accum(&d, a1 *% 2, a3);
    accum(&d, a2, a2);
    accum(&d, R << 12, @truncate(c));
    var t4: u64 = @as(u64, @truncate(d)) & M;
    d >>= 52;
    const tx: u64 = t4 >> 48;
    t4 &= M >> 4;

    c = @as(u128, a0) * @as(u128, a0);
    accum(&d, a1, a4);
    accum(&d, a2 *% 2, a3);
    var w: u64 = @as(u64, @truncate(d)) & M;
    d >>= 52;
    w = (w << 4) | tx;
    accum(&c, w, R >> 4);
    r[0] = @as(u64, @truncate(c)) & M;
    c >>= 52;

    a0 *%= 2;
    accum(&c, a0, a1);
    accum(&d, a2, a4);
    accum(&d, a3, a3);
    accum(&c, @as(u64, @truncate(d)) & M, R);
    d >>= 52;
    r[1] = @as(u64, @truncate(c)) & M;
    c >>= 52;

    accum(&c, a0, a2);
    accum(&c, a1, a1);
    accum(&d, a3, a4);
    accum(&c, R, @truncate(d));
    d >>= 64;
    r[2] = @as(u64, @truncate(c)) & M;
    c >>= 52;
    accum(&c, R << 12, @truncate(d));
    c += t3;
    r[3] = @as(u64, @truncate(c)) & M;
    c >>= 52;
    r[4] = @as(u64, @truncate(c)) +% t4;
}
