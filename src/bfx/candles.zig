const std = @import("std");
const Candle = @import("../models/candle.zig").Candle;
const http = std.http;
const heap = std.heap;
const json = std.json;
const time = std.time;

pub const Self = @This();

allocator: std.mem.Allocator,
interval_ns: u64,
mutex: std.Thread.Mutex,

pub fn init(allocator: std.mem.Allocator, interval_seconds: u64) !Self {
    return Self{
        .allocator = allocator,
        .interval_ns = interval_seconds * std.time.ns_per_s,
        .mutex = std.Thread.Mutex{},
    };
}

pub fn fetchCandles(
    self: *Self,
    pairs: [][]u8,
) ![]Candle {
    if (!self.mutex.tryLock()) {
        return error.AlreadyProcessing;
    }
    defer self.mutex.unlock();

    // create an ArrayList to collect candles
    var candles = std.ArrayList(Candle).init(self.allocator);

    for (pairs) |pair| {
        std.log.info("fetching for pair {s}\n", .{pair});
        if (self.fetchCandle(pair)) |candle| {
            try candles.append(candle);
        } else |err| {
            std.log.warn("failed to fetch candle for {s}: {any}", .{ pair, err });
        }

        // wait before next request
        if (pairs.len > 1) {
            std.time.sleep(self.interval_ns);
        }
    }

    return candles.toOwnedSlice();
}

pub fn fetchCandle(self: *Self, pair: []const u8) !Candle {
    var client = http.Client{ .allocator = self.allocator };
    defer client.deinit();

    var url_buf: [256]u8 = undefined;
    const url_str = try std.fmt.bufPrint(&url_buf, "https://api-pub.bitfinex.com/v2/candles/trade:1m:{s}/last", .{pair});

    var headBuf: [4096]u8 = undefined;
    const uri = try std.Uri.parse(url_str);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &headBuf });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    if (req.response.status != .ok) {
        return error.HttpRequestFailed;
    }

    const body = try req.reader().readAllAlloc(self.allocator, 256);
    defer self.allocator.free(body);

    var parsedBody = try json.parseFromSlice(json.Value, self.allocator, body, .{});
    defer parsedBody.deinit();

    if (parsedBody.value == .null) {
        return error.NullResponse;
    }

    if (parsedBody.value != .array) {
        return error.NotAnArrayResponse;
    }

    if (parsedBody.value.array.items.len < 6) {
        return error.InvalidCandleData;
    }

    return Candle{
        .exchange = "bitfinex",
        .pair = pair,
        .timestamp = try jsonToInt(parsedBody.value.array.items[0]),
        .open = try jsonToFloat(parsedBody.value.array.items[1]),
        .close = try jsonToFloat(parsedBody.value.array.items[2]),
        .high = try jsonToFloat(parsedBody.value.array.items[3]),
        .low = try jsonToFloat(parsedBody.value.array.items[4]),
        .volume = try jsonToFloat(parsedBody.value.array.items[5]),
    };
}

fn jsonToFloat(value: json.Value) !f64 {
    return switch (value) {
        .float => |v| v,
        .integer => |v| @floatFromInt(v),
        else => error.InvalidType,
    };
}

fn jsonToInt(value: json.Value) !i64 {
    return switch (value) {
        .integer => |v| v,
        .float => |v| @intFromFloat(v),
        else => return error.InvalidType,
    };
}
