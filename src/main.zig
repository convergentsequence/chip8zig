const std = @import("std");
const g = @import("graphics.zig");
const SDL = @import("sdl2");

fn clocked(comptime clock: usize, lastCycle: *i64, comptime callback: *const fn () anyerror!void) !void {
    const currentCycle = std.time.milliTimestamp();
    if (currentCycle - lastCycle.* >= 1000 / clock) {
        try callback();
        lastCycle.* = currentCycle;
    }
}

fn something() !void {
    std.debug.print("test\n", .{});
}

pub fn main() !void {
    var graphics = try g.Graphics.init(640 * 2, 320 * 2);
    defer graphics.quit();

    var lastCycle: i64 = 0;
    mainLoop: while (true) {
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => {
                    break :mainLoop;
                },
                .key_down => |key| {
                    switch (key.scancode) {
                        .escape => break :mainLoop,
                        else => std.log.info("key pressed: {}\n", .{key.scancode}),
                    }
                },

                else => {},
            }

        }
        try graphics.render();
        try clocked(60, &lastCycle, something);
    }
}
