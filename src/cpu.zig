const std = @import("std");
const SDL = @import("sdl2");
const opcodes = @import("opcodes.zig");

const print = std.debug.print;

pub const CPU = struct {
    const Self = @This();

    const CONTINUE_EMULATOR: bool = true;
    const STOP_EMULATOR: bool = false;

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
    ioBlock: isize = -1, // if io is blocked, stores the register where the keypress should be saved to
    delayTimer: u8 = 0,
    soundTimer: u8 = 0,
    graphicalBuffer: [64 * 32]u1,

    pub fn init() Self {
        return Self{
            .memory = std.mem.zeroes([4096]u8),
            .V = std.mem.zeroes([16]u8),
            .stack = std.mem.zeroes([16]u16),
            .keycodes = std.mem.zeroes([16]bool),
            .graphicalBuffer = std.mem.zeroes([32 * 64]u1),
        };
    }

    // returns false if emulator should exit
    pub fn handleIO(self: *Self, ev: SDL.Event) bool {
        var mapKey: ?usize = null;
        switch (ev) {
            .quit => {
                return STOP_EMULATOR;
            },
            .key_down, .key_up => |key| {
                mapKey = switch (key.scancode) {
                    .@"0", .keypad_0 => 0x0,
                    .@"1", .keypad_1 => 0x1,
                    .@"2", .keypad_2 => 0x2,
                    .@"3", .keypad_3 => 0x3,
                    .@"4", .keypad_4 => 0x4,
                    .@"5", .keypad_5 => 0x5,
                    .@"6", .keypad_6 => 0x6,
                    .@"7", .keypad_7 => 0x7,
                    .@"8", .keypad_8 => 0x8,
                    .@"9", .keypad_9 => 0x9,
                    .a => 0xA,
                    .b => 0xB,
                    .c => 0xC,
                    .d => 0xD,
                    .e => 0xE,
                    .f => 0xF,
                    .escape => return STOP_EMULATOR,
                    else => null,
                };
            },
            else => {},
        }

        if (mapKey) |key| self.keycodes[key] = ev == .key_down;
        if (mapKey != null and self.ioBlock >= 0 and ev == .key_down) {
            self.V[@intCast(self.ioBlock)] = @intCast(mapKey.?);
            self.ioBlock = -1;
        }

        return CONTINUE_EMULATOR;
    }

    pub fn decrementTimers(self: *Self) void {
        if(self.ioBlock != -1) return;
        if (self.delayTimer > 0) self.delayTimer -= 1;
        if (self.soundTimer > 0) self.soundTimer -= 1;
    }

    fn cycle(self: *Self) bool {
        var opcode: u16 = @as(u16, self.memory[self.PC]) << 8 | self.memory[self.PC + 1];
        if (opcode == 0) {
            print("Exiting, PC: 0x{X:0>3}, OPCODE: 0x{X:0>4}\n", .{ self.PC, opcode });
            return STOP_EMULATOR;
        }

        opcodes.handleOpcode(self, opcode);

        return CONTINUE_EMULATOR;
    }

    pub fn clockedCycle(self: *Self, clock: usize) bool {
        const micro = std.time.microTimestamp();
        if (micro - self.lastCycle >= 1_000_000 / clock) {
            self.lastCycle = micro;
            if (!(self.ioBlock != -1)) return self.cycle();
        }

        return CONTINUE_EMULATOR;
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

        //std.mem.copy(u8, &self.memory, &fontSet);
        @memcpy(self.memory[0..fontSet.len], fontSet[0..]);
    }
};
