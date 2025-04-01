const std = @import("std");
const http = std.http;
const heap = std.heap;
const json = std.json;

pub fn fetchTradingPairs(allocator: std.mem.Allocator) !std.ArrayList([]u8) {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var headBuf: [4096]u8 = undefined;
    const uri = try std.Uri.parse("https://api-pub.bitfinex.com/v2/conf/pub:list:pair:exchange");
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &headBuf });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    if (req.response.status != .ok) return error.HttpRequestFailed;

    const body = try req.reader().readAllAlloc(allocator, 1024 * 16);
    defer allocator.free(body);

    var parsedBody = try json.parseFromSlice(json.Value, allocator, body, .{});
    defer parsedBody.deinit();

    if (parsedBody.value.array.items.len == 0) return error.EmptyResponse;

    var parsedPairs = std.ArrayList([]u8).init(allocator);
    for (parsedBody.value.array.items[0].array.items) |pair| {
        const prefixed = try std.fmt.allocPrint(allocator, "t{s}", .{pair.string});
        try parsedPairs.append(prefixed);
    }

    return parsedPairs;
}
