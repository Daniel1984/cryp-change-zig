const std = @import("std");
const http = std.http;

pub fn get(allocator: std.mem.Allocator, url: []const u8, max_response_size: usize) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var headBuf: [4096]u8 = undefined;
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &headBuf });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    if (req.response.status != .ok) return error.HttpRequestFailed;

    return try req.reader().readAllAlloc(allocator, max_response_size);
}
