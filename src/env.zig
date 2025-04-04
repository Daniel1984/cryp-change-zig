const std = @import("std");

/// Allocator used for string operations
allocator: std.mem.Allocator,

/// Type alias for this module
const Env = @This();

/// Initialize the environment utility with an allocator
pub fn init(allocator: std.mem.Allocator) Env {
    return .{
        .allocator = allocator,
    };
}

/// Get an integer from an environment variable, with a default value if not found or invalid
pub fn getInt(self: *const Env, comptime T: type, name: []const u8, default_value: T) T {
    const str = std.process.getEnvVarOwned(self.allocator, name) catch {
        // Return default if not found
        return default_value;
    };
    defer self.allocator.free(str);

    // Try to parse as integer, return default if parsing fails
    return std.fmt.parseInt(T, str, 10) catch {
        return default_value;
    };
}
