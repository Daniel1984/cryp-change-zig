const std = @import("std");
const httpz = @import("httpz");

// You can add fields here if needed and pass them through init
// name: []const u8,
// db: Database,

pub const App = @This();

pub fn notFound(_: *App, req: *httpz.Request, res: *httpz.Response) !void {
    std.log.info("404 {} {s}", .{ req.method, req.url.path });
    res.status = 404;
    res.body = "Not Found";
}

pub fn uncaughtError(_: *App, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
    std.log.info("500 {} {s} {}", .{ req.method, req.url.path, err });
    res.status = 500;
    res.body = "sorry";
}

pub fn init() App {
    return .{
        // Initialize any fields here if you add them
    };
}
