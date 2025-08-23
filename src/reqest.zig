const std = @import("std");
const http = std.http;

pub fn get(allocator: std.mem.Allocator, url: []const u8, max_response_size: usize) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    var req = try client.request(.GET, uri, .{});
    defer req.deinit();

    try req.sendBodiless();
    var response = try req.receiveHead(&.{});

    if (response.head.status != .ok) return error.HttpRequestFailed;

    // Buffer for the reader
    var reader_buffer: [4096]u8 = undefined;
    var body_reader = response.reader(&reader_buffer);

    return try body_reader.readAlloc(allocator, max_response_size);
}
