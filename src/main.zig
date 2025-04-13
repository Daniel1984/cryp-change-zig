const std = @import("std");
const httpz = @import("httpz");
const zap = @import("zap");
const App = @import("./app.zig");
const Env = @import("./env.zig");
const healtCheck = @import("./handlers/health-check.zig");
const dummy = @import("./handlers/dummy.zig");
const bfx_svc = @import("./bfx/service.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var env = Env.init(allocator);
    const port: u16 = env.getInt(u16, "PORT", 5888);

    var bfxsvc = try bfx_svc.init(allocator);
    try bfxsvc.start();
    defer bfxsvc.stop();

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
