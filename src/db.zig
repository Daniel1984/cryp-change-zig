const std = @import("std");
const pg = @import("pg");
const Env = @import("./env.zig");
const Pool = pg.Pool;

pool: *Pool,
host: []const u8,
uname: []const u8,
pwd: []const u8,
db_name: []const u8,
allocator: std.mem.Allocator,

pub const Self = @This();

pub fn init(allocator: std.mem.Allocator) !*Self {
    var pool = try allocator.create(Self);

    var env = Env.init(allocator);

    pool.allocator = allocator;
    pool.host = env.getString("POSTGRES_HOST", "0.0.0.0");
    pool.uname = env.getString("POSTGRES_USER", "postgres");
    pool.pwd = env.getString("POSTGRES_PASSWORD", "password");
    pool.db_name = env.getString("POSTGRES_DB", "crypchange");

    pool.pool = try pg.Pool.init(allocator, .{ .size = 10, .connect = .{
        .port = env.getInt(u16, "POSTGRES_PORT", 5432),
        .host = pool.host,
    }, .auth = .{
        .username = pool.uname,
        .database = pool.db_name,
        .password = pool.pwd,
        .timeout = 10_000,
    } });

    return pool;
}

pub fn ping(self: *Self) !void {
    var conn = try self.pool.acquire();
    defer self.pool.release(conn);

    _ = try conn.query("SELECT 1", .{});
}

pub fn deinit(self: *Self) void {
    self.pool.deinit();
    self.allocator.free(self.host);
    self.allocator.free(self.uname);
    self.allocator.free(self.pwd);
    self.allocator.free(self.db_name);
    self.allocator.destroy(self);
}
