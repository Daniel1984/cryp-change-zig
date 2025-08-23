const std = @import("std");
const Candle = @import("../models/candle.zig").Candle;
const request = @import("../reqest.zig");
const DB = @import("../db.zig").Self;
const json = std.json;
const time = std.time;

pub const Self = @This();

allocator: std.mem.Allocator,
req_delay: u64,
mutex: std.Thread.Mutex,
db: *DB,

pub fn init(allocator: std.mem.Allocator, req_delay: u64, db: *DB) !Self {
    return Self{
        .allocator = allocator,
        .req_delay = req_delay * std.time.ns_per_s,
        .mutex = std.Thread.Mutex{},
        .db = db,
    };
}

pub fn fetchCandles(
    self: *Self,
    pairs: [][]u8,
) void {
    if (!self.mutex.tryLock()) {
        std.log.info("someone calling fetchCandles while its still running", .{});
        return;
    }
    defer self.mutex.unlock();

    for (pairs) |pair| {
        if (self.fetchCandle(pair)) |candle| {
            self.persist(candle);
        } else |err| {
            std.log.warn("failed to fetch bfx candle for {s}: {any}", .{ pair, err });
        }

        // wait before next request
        if (pairs.len > 1) {
            std.Thread.sleep(self.req_delay);
        }
    }

    return;
}

pub fn persist(self: *Self, c: Candle) void {
    _ = self.db.pool.exec(
        \\ insert into candles
        \\ (pair, exchange, h, l, o, c, v, timestamp)
        \\ values
        \\ ($1, $2, $3::double precision, $4::double precision, $5::double precision, $6::double precision, $7::double precision, $8)
    , .{
        c.pair,
        c.exchange,
        c.high,
        c.low,
        c.open,
        c.close,
        c.volume,
        c.timestamp,
    }) catch |err| {
        std.log.err("failed inserting candle data {any}: {}", .{ c, err });
    };
}

pub fn fetchCandle(self: *Self, pair: []const u8) !Candle {
    var url_buf: [256]u8 = undefined;
    const url_str = try std.fmt.bufPrint(&url_buf, "https://api-pub.bitfinex.com/v2/candles/trade:1m:{s}/last", .{pair});
    const body = try request.get(self.allocator, url_str, 256);
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
