const std = @import("std");
const linux = std.os.linux;
const lib = @import("hd");

const PHRASE =
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

fn nowNs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(linux.CLOCK.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

pub fn main() !void {
    const seed = try lib.mnemonicToSeed(PHRASE);
    const rounds: u64 = 5_000;
    std.mem.doNotOptimizeAway(try lib.btcP2wpkh(&seed));

    var t0 = nowNs();
    var i: u64 = 0;
    while (i < rounds) : (i += 1) {
        std.mem.doNotOptimizeAway(try lib.btcP2wpkh(&seed));
    }
    const btc_ns = (nowNs() - t0) / rounds;

    t0 = nowNs();
    i = 0;
    var buf: [44]u8 = undefined;
    while (i < rounds) : (i += 1) {
        std.mem.doNotOptimizeAway(try lib.solAddress(&seed, &buf));
    }
    const sol_ns = (nowNs() - t0) / rounds;

    std.debug.print("btc p2wpkh  {d} ns/op  ({d} rounds)\n", .{ btc_ns, rounds });
    std.debug.print("sol slip10  {d} ns/op  ({d} rounds)\n", .{ sol_ns, rounds });
}
