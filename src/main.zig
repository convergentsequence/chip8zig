const std = @import("std");

pub fn main() !void {
    std.debug.print("Start\n", .{});
    defer std.debug.print("End\n", .{});
}
