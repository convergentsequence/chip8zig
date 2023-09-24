const std = @import("std");
const c = @import("cpu.zig");
const SDL = @import("sdl2");

const print = std.debug.print;

pub const Graphics = struct {
    const Self = @This();
    window: SDL.Window,
    renderer: SDL.Renderer,
    lastRender: i64 = 0,

    pub fn init(w: usize, h: usize) !Self {
        try SDL.init(.{
            .video = true,
            .events = true,
            .audio = true,
        });
        errdefer SDL.quit();

        var window = try SDL.createWindow(
            "CHIP-8 Emulator",
            .{ .centered = {} },
            .{ .centered = {} },
            w,
            h,
            .{ .vis = .shown },
        );
        errdefer window.destroy();

        var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
        errdefer renderer.destroy();

        try renderer.setLogicalSize(64, 32);

        try renderer.setColorRGB(0, 0, 0);
        try renderer.clear();

        return Self{
            .window = window,
            .renderer = renderer,
        };
    }

    fn renderGraphicalBuffer(self: *Self, cpu: *c.CPU) !void {
        var pixel: u8 = 0;
        for (0..64) |i| {
            for (0..32) |j| {
                pixel = @as(u8, @intFromBool(cpu.graphicalBuffer[i + j * 64])) * 255;

                try self.renderer.setColorRGB(pixel, pixel, pixel);
                try self.renderer.drawPoint(@intCast(i), @intCast(j));
            }
        }
    }

    fn render(self: *Self, CPU: *c.CPU) !void {
        CPU.decrementTimers();
        try self.renderGraphicalBuffer(CPU);
        self.renderer.present();
    }

    pub fn clocked_render(self: *Self, CPU: *c.CPU) !void {
        const current = std.time.milliTimestamp();
        if (current - self.lastRender >= 1000 / 60) {
            try self.render(CPU);
            self.lastRender = current;
        }
    }

    pub fn quit(self: *Self) void {
        self.renderer.destroy();
        self.window.destroy();
        SDL.quit();
    }
};
