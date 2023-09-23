const std = @import("std");
const g = @import("graphics.zig");
const c = @import("cpu.zig");
const SDL = @import("sdl2");

pub fn main() !void {
    var graphics = try g.Graphics.init(640 * 2, 320 * 2);
    defer graphics.quit();

    var CPU = c.CPU.init();

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
        try CPU.clocked_cycle(60);
    }
}
