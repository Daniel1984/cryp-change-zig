const std = @import("std");
const tp = @import("./trading-pairs.zig");
const c = @import("./candles.zig");

pub const Self = @This();

allocator: std.mem.Allocator,
trading_pairs: tp.Self,
candles: c.Self,
is_running: bool,
thread: ?std.Thread,
mutex: std.Thread.Mutex,

pub fn init(allocator: std.mem.Allocator) !Self {
    const trading_pairs_svc = try tp.Self.init(allocator, 300);
    const candles_svc = try c.Self.init(allocator, 2);

    return .{
        .allocator = allocator,
        .trading_pairs = trading_pairs_svc,
        .candles = candles_svc,
        .is_running = false,
        .thread = null,
        .mutex = std.Thread.Mutex{},
    };
}

pub fn deinit(self: *Self) void {
    self.stop();
    self.trading_pairs.deinit();
}

pub fn start(self: *Self) !void {
    if (self.is_running) return;

    try self.trading_pairs.start();
    self.is_running = true;
    self.thread = try std.Thread.spawn(.{}, updateLoop, .{self});
}

pub fn stop(self: *Self) void {
    if (!self.is_running) return;

    self.is_running = false;
    self.trading_pairs.stop();

    if (self.thread) |thread| {
        thread.join();
        self.thread = null;
    }
}

fn updateLoop(self: *Self) void {
    while (self.is_running) {
        if (self.trading_pairs.getPairs()) |pairs| {
            defer self.allocator.free(pairs);
            self.candles.fetchCandles(pairs);
        } else |err| {
            std.log.err("failed to get trading pairs: {any}", .{err});
        }

        std.time.sleep(5 * std.time.ns_per_s);
    }
}
