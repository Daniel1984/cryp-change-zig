const std = @import("std");
const httpz = @import("httpz");
const App = @import("../app.zig").App;

pub fn get(_: *App, req: *httpz.Request, res: *httpz.Response) !void {
    // Get the ID parameter
    const id = req.param("id") orelse {
        std.log.err("400 {} {s} - Missing 'id' parameter", .{ req.method, req.url.path });
        res.status = 400;
        res.body = "Missing 'id' parameter";
        return;
    };

    // Try to send the JSON response
    res.json(.{ .id = id, .message = "dummy" }, .{}) catch |err| {
        std.log.err("500 {} {s} - Error sending JSON: {}", .{ req.method, req.url.path, err });
        // Re-throw the error so it can be handled by the uncaughtError handler
        return err;
    };

    std.log.info("200 {} {s} - Successfully retrieved user {s}", .{ req.method, req.url.path, id });
}
