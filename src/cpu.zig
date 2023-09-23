const std = @import("std");

const print = std.debug.print;

pub const CPU = struct {
    const Self = @This();

    const fontSet = [_]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };

    memory: [4096]u8,
    lastCycle: i64,

    pub fn init() Self {
        return Self{
            .memory = std.mem.zeroes([4096]u8),
            .lastCycle = 0,
        };
    }

    fn cycle(self: *Self) !void {
        _ = self;
        //print("cycle\n", .{});
    }

    pub fn clocked_cycle(self: *Self, comptime clock: usize) !void {
        const millis = std.time.milliTimestamp();
        if (millis - self.lastCycle >= 1000 / clock) {
            self.lastCycle = millis;
            try self.cycle();
        }
    }

    pub fn loadFileToMem(self: *Self, pth: []const u8) !void {
        print("Opening ROM: {s}\n", .{pth});

        var file = std.fs.cwd().openFile(pth, .{}) catch |err| {
            print("Error opening provided ROM\n", .{});
            return err;
        };

        const fsize = (try file.stat()).size;

        print("ROM Size: {d}\n", .{fsize});
        if (!(fsize <= 0x200) and fsize - 0x200 > 4096) {
            print("ROM file too large! (Size: {d})\n", .{fsize});
            return (error{ROMTooLarge}).ROMTooLarge;
        }

        _ = try file.readAll(self.memory[0x200..]);

        // load fontset into memory
        std.mem.copy(u8, &self.memory, &fontSet);
    }
};
