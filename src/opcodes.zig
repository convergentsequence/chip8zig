const std = @import("std");
const CPU = @import("cpu.zig").CPU;

const print = std.debug.print;
const fmt = std.fmt;

const VERBOSE_OPCODES: bool = true;

inline fn verboseOpcode(PC: u16, opcode: u16, msg: [:0]const u8) void {
    if (!VERBOSE_OPCODES) return;

    std.debug.print("0x{X:0>3}: 0x{X:0>4} {s}\n", .{ PC - 2, opcode, msg });
}

inline fn verboseOpcodeFmt(PC: u16, opcode: u16, msg: [:0]const u8, args: anytype) void {
    if (!VERBOSE_OPCODES) return;

    std.debug.print("0x{X:0>3}: 0x{X:0>4} ", .{ PC - 2, opcode});
    std.debug.print(msg, args);
    std.debug.print("\n", .{});
}

/// unknown opcode
inline fn opcodeUnknown(cpu: *CPU, opcode: u16) void {
    verboseOpcode(cpu.PC, opcode, "Unknown Opcode");
}

// 0x00E0 -> clear screen
inline fn opcodeCLS(cpu: *CPU, opcode: u16) void {
    verboseOpcode(cpu.PC, opcode, "Clearing screen");
    @memset(cpu.graphicalBuffer[0 .. 32 * 64], false);
}

// 0x00EE -> return from subroutine call
inline fn opcodeRET(cpu: *CPU, opcode: u16) void {
    verboseOpcodeFmt(cpu.PC, opcode, "Returning from subroutine to: 0x{X:0>3}", .{cpu.stack[cpu.SP - 1]});
    cpu.SP -= 1;
    cpu.PC = cpu.stack[cpu.SP];
}

// 0x1NNN -> jump to location NNN
inline fn opcodeJMP(cpu: *CPU, opcode: u16) void {
    const NNN: u16 = opcode & 0x0FFF;
    verboseOpcodeFmt(cpu.PC, opcode, "Jumping to location 0x{X:0>3}", .{NNN});
    cpu.PC = NNN;
}

// 0x2NNN -> jump to subroutine at NNN
inline fn opcodeCALL(cpu: *CPU, opcode: u16) void {
    const NNN: u16 = opcode & 0x0FFF;
    verboseOpcodeFmt(cpu.PC, opcode, "Jumping to subroutine at 0x{X:0>3}", .{NNN});
    cpu.stack[cpu.SP] = cpu.PC;
    cpu.SP += 1;
    cpu.PC = NNN;
}

pub fn handleOpcode(cpu: *CPU, opcode: u16) void {
    cpu.PC += 2;
    switch ((opcode & 0xF000) >> 12) {
        0x0 => {
            switch (opcode & 0x00FF) {
                0xE0 => opcodeCLS(cpu, opcode),
                0xEE => opcodeRET(cpu, opcode),
                else => opcodeUnknown(cpu, opcode),
            }
        },
        0x1 => opcodeJMP(cpu, opcode),
        0x2 => opcodeCALL(cpu, opcode),
        else => opcodeUnknown(cpu, opcode),
    }
}
