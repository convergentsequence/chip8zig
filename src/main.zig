const std = @import("std");
const g = @import("graphics.zig");
const c = @import("cpu.zig");
const SDL = @import("sdl2");

const print = std.debug.print;


fn getRomPath() ![:0]const u8 {
    var args = std.process.args();
    _ = args.next();
    const target = args.next();
    if (target == null) {
        print("You need to provide a ROM file to run", .{});
        return (error {NoRomProvided}).NoRomProvided;
    }

    return target.?;
}

pub fn main() !void {
    print("Starting emulator...\n", .{});
    defer print("Stopping emulator...\n", .{});

    const romPath = try getRomPath();
    print("ROM path: {s}\n", .{romPath});

    var graphics = try g.Graphics.init(640 * 2, 320 * 2);
    defer graphics.quit();

    var CPU = c.CPU.init();
    try CPU.loadFileToMem(romPath);

    mainLoop: while (true) {
        while (SDL.pollEvent()) |ev| {
            if (!CPU.handle_io(ev)) break :mainLoop;
        }
        try graphics.clocked_render(&CPU);
        if(!try CPU.clocked_cycle(500)) break;
    }
}
