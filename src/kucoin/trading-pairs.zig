// get all trading pairs: GET https://api.kucoin.com/api/v1/market/stats?symbol=TROLL-USDT

// get OCHLV for a pair: GET https://api.kucoin.com/api/v1/market/stats?symbol=TROLL-USDT

// curl https://api.kucoin.com/api/v1/market/candles\?type\=1day\&symbol\=TROLL-USDT
//
// last one returns raw data:
// {
//   "code": "200000",
//   "data": [
//     [
//       "1651027200", // Time
//       "0.033",      // Open
//       "0.037",      // High
//       "0.032",      // Low
//       "0.0345",     // Close
//       "58482.123"   // Volume
//     ]
//   ]
// }
//
const std = @import("std");
const request = @import("../reqest.zig");
const json = std.json;
const time = std.time;

pub const Self = @This();

allocator: std.mem.Allocator,
pairs: [][]u8,
interval_ns: u64,
is_running: bool,
thread: ?std.Thread,
mutex: std.Thread.Mutex,

pub fn init(allocator: std.mem.Allocator, interval_seconds: u64) !Self {
    return Self{
        .allocator = allocator,
        .pairs = &[_][]u8{},
        .interval_ns = interval_seconds * time.ns_per_s,
        .is_running = false,
        .thread = null,
        .mutex = std.Thread.Mutex{},
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.pairs);
    self.stop();
}

pub fn start(self: *Self) !void {
    if (self.is_running) return error.ServiceAlreadyRunning;

    if (fetchTradingPairs(self.allocator)) |pairs| {
        self.pairs = pairs;
    } else |err| {
        std.log.warn("err making initial fetchTradingPairs call: {}", .{err});
    }

    self.is_running = true;
    self.thread = try std.Thread.spawn(.{}, fetchLoop, .{self});
}

pub fn stop(self: *Self) void {
    if (!self.is_running) return;

    self.is_running = false;
    if (self.thread) |thread| {
        thread.join();
        self.thread = null;
    }
}

pub fn getPairs(self: *Self) ![][]u8 {
    self.mutex.lock();
    defer self.mutex.unlock();

    var result = std.ArrayList([]u8){};
    for (self.pairs) |pair| {
        const prefixed = try std.fmt.allocPrint(self.allocator, "t{s}", .{pair});
        try result.append(self.allocator, prefixed);
    }
    return result.toOwnedSlice(self.allocator);
}

fn fetchLoop(self: *Self) void {
    while (self.is_running) {
        if (fetchTradingPairs(self.allocator)) |new_pairs| {
            self.mutex.lock();
            self.allocator.free(self.pairs);
            self.pairs = new_pairs;
            self.mutex.unlock();
        } else |err| {
            std.log.err("failed to fetch trading pairs: {any}", .{err});
        }

        std.Thread.sleep(self.interval_ns);
    }
}

fn fetchTradingPairs(allocator: std.mem.Allocator) ![][]u8 {
    const body = try request.get(allocator, "https://api.kucoin.com/api/v1/symbols", 1024 * 1024);
    defer allocator.free(body);

    var parsedBody = try json.parseFromSlice(json.Value, allocator, body, .{});
    defer parsedBody.deinit();

    if (parsedBody.value == .null) {
        return error.NullResponse;
    }

    if (parsedBody.value != .object) {
        return error.NotAnObjectResponse;
    }

    const dataField = parsedBody.value.object.get("data") orelse {
        return error.NoDataField;
    };

    if (dataField != .array) {
        return error.DataNotAnArray;
    }

    if (dataField.array.items.len == 0) {
        return error.EmptyResponse;
    }

    var resPairs = std.ArrayList([]u8){};
    for (dataField.array.items) |item| {
        if (item != .object) continue;

        const symbolField = item.object.get("symbol") orelse continue;
        if (symbolField != .string) continue;

        const symbol = symbolField.string;

        if (std.mem.endsWith(u8, symbol, "-USD") or
            std.mem.endsWith(u8, symbol, "-USDT") or
            std.mem.endsWith(u8, symbol, "-USDC"))
        {
            const symbol_copy = try allocator.dupe(u8, symbol);
            try resPairs.append(allocator, symbol_copy);
        }
    }

    return resPairs.toOwnedSlice(allocator);
}
