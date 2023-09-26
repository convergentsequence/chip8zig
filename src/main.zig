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

const defaultClock = 1000;
fn getClockSpeed() !usize {
    var args = std.process.args();
    _ = args.next();
    _ = args.next();
    const clock = args.next();

    if (clock == null) return defaultClock;
    return try std.fmt.parseUnsigned(usize, clock.?, 10);
}

pub fn main() !void {
    print("Starting emulator...\n", .{});
    defer print("Stopping emulator...\n", .{});

    const romPath = try getRomPath();
    const clock = try getClockSpeed();

    var graphics = try g.Graphics.init(640 * 2, 320 * 2);
    defer graphics.quit();

    var cpu = c.CPU.init();
    try cpu.loadFileToMem(romPath);

    mainLoop: while (true) {
        while (SDL.pollEvent()) |ev| {
            if (!cpu.handleIO(ev)) break :mainLoop;
        }
        try graphics.clockedRender(&cpu);
        if(!cpu.clockedCycle(clock)) break;
    }
}
