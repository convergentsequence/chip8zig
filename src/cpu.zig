const std = @import("std");
const SDL = @import("sdl2");
const opcodes = @import("opcodes.zig");

const print = std.debug.print;

const VerboseOpcode: bool = true;

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
    lastCycle: i64 = 0,
    V: [16]u8,
    stack: [16]u16,
    SP: u8 = 0,
    PC: u16 = 0x200,
    I: u16 = 0,
    keycodes: [16]bool,
    keycode: i32 = 0,
    ioBlock: bool = false,
    delayTimer: u8 = 0,
    soundTimer: u8 = 0,
    graphicalBuffer: [64 * 32]bool,

    pub fn init() Self {
        return Self{
            .memory = std.mem.zeroes([4096]u8),
            .V = std.mem.zeroes([16]u8),
            .stack = std.mem.zeroes([16]u16),
            .keycodes = std.mem.zeroes([16]bool),
            .graphicalBuffer = std.mem.zeroes([32 * 64]bool),
        };
    }

    inline fn verboseOpcode(PC: u16, opcode: u16, msg: [:0]const u8) void {
        if (VerboseOpcode)
            print("0x{X:0>3}: 0x{X:0>4} {s}\n", .{ PC, opcode, msg });
    }

    // returns false if emulator should exit
    pub fn handleIO(self: *Self, ev: SDL.Event) bool {
        _ = self;
        switch (ev) {
            .quit => {
                return false;
            },
            .key_down => |key| {
                switch (key.scancode) {
                    .escape => return false,
                    else => {},
                }
            },
            else => {},
        }
        return true;
    }

    pub fn decrementTimers(self: *Self) void {
        if (self.delayTimer > 0) self.delayTimer -= 1;
        if (self.soundTimer > 0) self.soundTimer -= 1;
    }

    fn cycle(self: *Self) !bool {
        var opcode: u16 = @as(u16, self.memory[self.PC]) << 8 | self.memory[self.PC + 1];
        if (opcode == 0) {
            print("Exiting, PC: 0x{X:0>3}, OPCODE: 0x{X:0>4}\n", .{ self.PC, opcode });
            return false;
        }

        opcodes.handleOpcode(self, opcode);

        return true;
    }

    pub fn clockedCycle(self: *Self, comptime clock: usize) !bool {
        const millis = std.time.milliTimestamp();
        if (millis - self.lastCycle >= 1000 / clock) {
            if (!self.ioBlock) return try self.cycle();
            self.lastCycle = millis;
        }

        return true;
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

        std.mem.copy(u8, &self.memory, &fontSet);
    }
};
