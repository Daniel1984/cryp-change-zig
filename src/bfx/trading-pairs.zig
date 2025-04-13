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
        std.log.warn("err making initial fetchTradingPairs call: {!}", .{err});
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

    var result = std.ArrayList([]u8).init(self.allocator);
    for (self.pairs) |pair| {
        const prefixed = try std.fmt.allocPrint(self.allocator, "t{s}", .{pair});
        try result.append(prefixed);
    }
    return result.toOwnedSlice();
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

        std.time.sleep(self.interval_ns);
    }
}

fn fetchTradingPairs(allocator: std.mem.Allocator) ![][]u8 {
    const body = try request.get(allocator, "https://api-pub.bitfinex.com/v2/conf/pub:list:pair:exchange", 1024 * 16);
    defer allocator.free(body);

    var parsedBody = try json.parseFromSlice(json.Value, allocator, body, .{});
    defer parsedBody.deinit();

    if (parsedBody.value == .null) {
        return error.NullResponse;
    }

    if (parsedBody.value != .array) {
        return error.NotAnArrayResponse;
    }

    if (parsedBody.value.array.items.len == 0) return error.EmptyResponse;
    if (parsedBody.value.array.items[0] != .array) return error.InvalidResponseFormat;
    if (parsedBody.value.array.items[0].array.items.len == 0) return error.EmptyResponse;

    var resPairs = std.ArrayList([]u8).init(allocator);
    for (parsedBody.value.array.items[0].array.items) |pair| {
        const pair_copy = try allocator.dupe(u8, pair.string);
        try resPairs.append(pair_copy);
    }

    return resPairs.toOwnedSlice();
}
