const std = @import("std");
const httpz = @import("httpz");
const App = @import("../app.zig").App;

pub fn get(_: *App, req: *httpz.Request, res: *httpz.Response) !void {
    std.log.info("200 {} {s}", .{ req.method, req.url.path });
    try res.json(.{ .status = "OK" }, .{});
}
