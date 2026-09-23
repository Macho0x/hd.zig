pub const btc = @import("btc.zig");
pub const sol = @import("sol.zig");

pub const mnemonicToSeed = btc.mnemonicToSeed;
pub const btcP2wpkh = btc.p2wpkh;
pub const solAddress = sol.addressInto;

test {
    _ = btc;
    _ = sol;
    _ = @import("ecmult_gen.zig");
    _ = @import("field_5x52.zig");
}
