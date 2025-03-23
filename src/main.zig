const std = @import("std");
const httpz = @import("httpz");
const zap = @import("zap");
const App = @import("./app.zig");
const healtCheck = @import("./handlers/health-check.zig");
const dummy = @import("./handlers/dummy.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = App.init();
    var server = try httpz.Server(*App).init(allocator, .{ .port = 5882 }, &app);
    var router = try server.router(.{});

    router.get("/dummy/:id", dummy.get, .{});
    router.get("/status", healtCheck.get, .{});

    // start the server in the current thread, blocking.
    try server.listen();
}
