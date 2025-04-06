const std = @import("std");
const httpz = @import("httpz");
const zap = @import("zap");
const App = @import("./app.zig");
const Env = @import("./env.zig");
const healtCheck = @import("./handlers/health-check.zig");
const dummy = @import("./handlers/dummy.zig");
const bfx_trading_pairs = @import("./bfx/trading-pairs.zig");
const bfx_candles = @import("./bfx/candles.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var env = Env.init(allocator);
    const port: u16 = env.getInt(u16, "PORT", 5888);

    var bfx_tp = try bfx_trading_pairs.init(allocator, 10);
    try bfx_tp.start();

    const bfx_pairs = try bfx_tp.getPairs();
    // debug
    // for (bfx_pairs) |pair| {
    //     std.debug.print("bfx pair: {s}\n", .{pair});
    // }

    var bfxCndls = try bfx_candles.init(allocator, 2);
    const candles = try bfxCndls.fetchCandles(bfx_pairs);
    std.debug.print("bfx candles: {any}\n", .{candles[0]});

    var app = App.init();
    var server = try httpz.Server(*App).init(allocator, .{ .port = port, .address = "0.0.0.0" }, &app);

    defer server.deinit();
    defer server.stop();

    var router = try server.router(.{});
    router.get("/dummy/:id", dummy.get, .{});
    router.get("/status", healtCheck.get, .{});

    std.log.info("server started at port: {d}", .{port});
    try server.listen();
}
