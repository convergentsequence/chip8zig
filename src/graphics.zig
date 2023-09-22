const std = @import("std");
const SDL = @import("sdl2");

const print = std.debug.print;

pub const Graphics = struct {
    const Self = @This();
    window: SDL.Window,
    renderer: SDL.Renderer,

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

        return Self{
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn render(self: *Self) !void {
        try self.renderer.setColorRGB(0, 0, 0);
        try self.renderer.clear();

        self.renderer.present();
    }

    pub fn quit(self: *Self) void {
        self.renderer.destroy();
        self.window.destroy();
        SDL.quit();
    }
};
