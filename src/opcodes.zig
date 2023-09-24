const std = @import("std");
const CPU = @import("cpu.zig").CPU;

const print = std.debug.print;
const fmt = std.fmt;

const VERBOSE_OPCODES: bool = false;

var cpu: *CPU = undefined;
var opcode: u16 = 0x0000;

inline fn verboseOpcode(msg: [:0]const u8) void {
    if (!VERBOSE_OPCODES) return;

    std.debug.print("0x{X:0>3}: 0x{X:0>4} {s}\n", .{ cpu.PC - 2, opcode, msg });
}

inline fn verboseOpcodeFmt(msg: [:0]const u8, args: anytype) void {
    if (!VERBOSE_OPCODES) return;

    std.debug.print("0x{X:0>3}: 0x{X:0>4} ", .{ cpu.PC - 2, opcode});
    std.debug.print(msg, args);
    std.debug.print("\n", .{});
}

/// unknown opcode
inline fn opcodeUnknown() void {
    verboseOpcode("Unknown Opcode");
}

/// 0x00E0 -> clear screen
inline fn opcodeCLS() void {
    verboseOpcode("Clearing screen");
    @memset(cpu.graphicalBuffer[0 .. 32 * 64], 0);
}

/// 0x00EE -> return from subroutine call
inline fn opcodeRET() void {
    verboseOpcodeFmt("Returning from subroutine to: 0x{X:0>3}", .{cpu.stack[cpu.SP - 1]});
    cpu.SP -= 1;
    cpu.PC = cpu.stack[cpu.SP];
}

/// 0x1NNN -> jump to location NNN
inline fn opcodeJMP() void {
    const NNN: u16 = opcode & 0x0FFF;
    verboseOpcodeFmt("Jumping to location 0x{X:0>3}", .{NNN});
    cpu.PC = NNN;
}

/// 0x2NNN -> jump to subroutine at NNN
inline fn opcodeCALL() void {
    const NNN: u16 = opcode & 0x0FFF;
    verboseOpcodeFmt("Jumping to subroutine at 0x{X:0>3}", .{NNN});
    cpu.stack[cpu.SP] = cpu.PC;
    cpu.SP += 1;
    cpu.PC = NNN;
}

pub fn handleOpcode(_cpu: *CPU, _opcode: u16) void {
    cpu = _cpu;
    opcode = _opcode;

    cpu.PC += 2;
    switch ((opcode & 0xF000) >> 12) {
        0x0 => {
            switch (opcode & 0x00FF) {
                0xE0 => opcodeCLS(),
                0xEE => opcodeRET(),
                else => opcodeUnknown(),
            }
        },
        0x1 => opcodeJMP(),
        0x2 => opcodeCALL(),
        else => opcodeUnknown(),
    }
}
