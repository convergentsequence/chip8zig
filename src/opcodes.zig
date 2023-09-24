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

    std.debug.print("0x{X:0>3}: 0x{X:0>4} ", .{ cpu.PC - 2, opcode });
    std.debug.print(msg, args);
    std.debug.print("\n", .{});
}

/// extracts value masked by argument from current opcode
///
/// example:
///     opcode = 0xABCD;
///     const extracted = extract(0x0FF0);
///
/// extracted is not equal to 0x00BC
inline fn extract(comptime mask: u16) u16 {
    const masked = opcode & mask;

    comptime var i: u4 = 0;
    inline while ((mask >> i) & 1 == 0) i += 1;

    return masked >> i;
}

/// unknown opcode
inline fn opcodeUnknown() void {
    print("Unknown!!!!!!!!!!!!\n", .{});
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
    const NNN: u16 = extract(0xFFF);

    verboseOpcodeFmt("Jumping to location 0x{X:0>3}", .{NNN});

    cpu.PC = NNN;
}

/// 0x2NNN -> jump to subroutine at NNN
inline fn opcodeCALL() void {
    const NNN: u16 = extract(0xFFF);

    verboseOpcodeFmt("Jumping to subroutine at 0x{X:0>3}", .{NNN});

    cpu.stack[cpu.SP] = cpu.PC;
    cpu.SP += 1;
    cpu.PC = NNN;
}

/// 0x3XRR -> Skip next intruction if V[X] == RR
inline fn opcodeSKPEQ() void {
    const X = extract(0xF00);
    const RR = extract(0xFF);

    verboseOpcodeFmt("Skipping next instruction if V{X}({d}) == 0x{X}", .{ X, cpu.V[X], RR });

    if (cpu.V[X] == RR) cpu.PC += 2;
}

/// 0x4XRR -> skip next intruction if V[X] != RR
inline fn opcodeSKPNEQ() void {
    const X = extract(0xF00);
    const RR = extract(0xFF);

    verboseOpcodeFmt("Skipping next instruction if V{X}({d}) != 0x{X}", .{ X, cpu.V[X], RR });

    if (cpu.V[X] != RR) cpu.PC += 2;
}

/// 0x5XRR -> skip next instruction if V[X] == V[Y]
inline fn opcodeSKPEQV() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Skipping next instruction if V{X}({d}) == V{X}({d})", .{ X, cpu.V[X], Y, cpu.V[Y] });

    if (cpu.V[X] == cpu.V[Y]) cpu.PC += 1;
}

/// 0x6XRR -> move constant RR into V[X]
inline fn opcodeMOV() void {
    const X = extract(0xF00);
    const RR: u8 = @intCast(extract(0xFF));

    verboseOpcodeFmt("Moving 0x{X} into V{X}", .{ RR, X });
    cpu.V[X] = RR;
}

/// 0x7XRR -> add constant RR to V[X]
inline fn opcodeADD() void {
    const X = extract(0xF00);
    const RR: u8 = @intCast(extract(0xFF));

    verboseOpcodeFmt("Adding 0x{X} to V{X}({d})", .{ RR, X, cpu.V[X] });

    @setRuntimeSafety(false);
    cpu.V[X] += RR;
}

/// 0x8XY0 -> move V[Y] into V[X]
inline fn opcodeMOVV() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Moving V{X}({d}) into V{X}", .{ Y, cpu.V[Y], X });

    cpu.V[X] = cpu.V[Y];
}

/// 0x8XY1 -> stores the result of V[X] | V[Y] into V[X]
inline fn opcodeOR() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Storing V{X}({d}) | V{X}({d}) => V{X} ", .{ X, cpu.V[X], Y, cpu.V[Y], X });

    cpu.V[X] = cpu.V[X] | cpu.V[Y];
}

/// 0x8XY2 -> add V[Y] to V[X]
inline fn opcodeADDV() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Adding V{X}({d}) to V{X}({d})", .{ Y, cpu.V[Y], X, cpu.V[X] });

    @setRuntimeSafety(false);
    cpu.V[X] += cpu.V[Y];
}

/// 0x8XY3 -> stores the result of V[X] xor V[Y] into V[X]
inline fn opcodeXOR() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Storing V{X}({d}) xor V{X}({d}) => V{X}", .{ X, cpu.V[X], Y, cpu.V[Y], X });

    cpu.V[X] ^= cpu.V[Y];
}

/// 0x8XY4 -> add V[Y] to V[X] store carry in V[0xF]
inline fn opcodeADDVC() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Adding V{X}({d}) to V{X}({d}) and storing carry in VF", .{ Y, cpu.V[Y], X, cpu.V[X] });

    const sum: u16 = @as(u16, cpu.V[X]) + @as(u16, cpu.V[Y]);
    cpu.V[0xF] = @intFromBool(sum > 255);

    @setRuntimeSafety(false);
    cpu.V[X] += cpu.V[Y];
}

/// 0x8XY5 -> Subtract V[Y] from V[X] andstore the borrow in V[0xF]
inline fn opcodeSUBVC() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Subtracting V{X}({d}) from V{X}({d}) and storing carry in VF", .{ Y, cpu.V[Y], X, cpu.V[X] });
    cpu.V[0xF] = @intFromBool(cpu.V[X] > cpu.V[Y]);

    @setRuntimeSafety(false);
    cpu.V[X] -= cpu.V[Y];
}

/// 0x8X06 -> Shift V[X] to right, first bit goes to V[0xF]
inline fn opcodeRSHIFT() void {
    const X = extract(0xF00);

    verboseOpcodeFmt("Shifting V{X}({d}) right and storing first bit in VF", .{ X, cpu.V[X] });
    cpu.V[0xF] = cpu.V[X] & 1;
    cpu.V[X] >>= 1;
}

/// 0x8XY7 -> Subtract V[X] from V[Y] result stored in V[X] and borrow in V[0xF]
inline fn opcodeSUBYVC() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    cpu.V[0xF] = @intFromBool(cpu.V[Y] > cpu.V[X]);

    verboseOpcodeFmt("Subtracting V{X}({d}) from V{X}({d}) result => V{X} carry => VF", .{ X, cpu.V[X], Y, cpu.V[Y], X });

    @setRuntimeSafety(false);
    cpu.V[X] = cpu.V[Y] - cpu.V[X];
}

/// 0x8X0E -> shift V[X] to the left, most significant bit goest o V[0xF]
inline fn opcodeLSHIFT() void {
    const X = extract(0xF00);

    verboseOpcodeFmt("Shifting V{X}({d}) left and storing most significant bit in VF", .{ X, cpu.V[X] });

    cpu.V[0xF] = cpu.V[X] >> 7;
    cpu.V[0xF] <<= 1;
}

/// 0x9XYN -> skip next instruction if V[X] != V[Y]
inline fn opcodeSKPNEQV() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);

    verboseOpcodeFmt("Skipping next instruction if V{X}({d}) != V{X}({d})", .{ X, cpu.V[X], Y, cpu.V[Y] });

    if (cpu.V[X] != cpu.V[Y]) cpu.PC += 2;
}

/// 0xANNN -> move NNN into the I register
inline fn opcodeMOVI() void {
    const NNN = extract(0xFFF);

    verboseOpcodeFmt("Moving 0x{X} into I", .{NNN});

    cpu.I = NNN;
}

/// 0xANNN -> jump to address NNN + reigster V[0x0]
inline fn opcodeJMPO() void {
    const NNN = extract(0xFFF);

    verboseOpcodeFmt("Jumping to address 0x{X} + V0(0x{X})", .{ NNN, cpu.V[0] });

    cpu.PC = NNN + cpu.V[0];
}

/// 0xCXKK -> set V[X] to random number between 0 - 255 & KK
inline fn opcodeRAND() void {
    const X = extract(0xF00);
    const KK: u8 = @intCast(extract(0xFF));

    var rand_impl = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random: u8 = rand_impl.random().int(u8) & KK;

    verboseOpcodeFmt("Setting V{X} to random num: {d}", .{ X, random });

    cpu.V[X] = random;
}

/// Dxyn - DRW Vx, Vy, nibble
/// Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
/// The interpreter reads n bytes from memory, starting at the address stored in I. These bytes are then displayed as sprites on screen at coordinates (Vx, Vy). Sprites are XORed onto the existing screen.
/// If this causes any pixels to be erased, VF is set to 1, otherwise it is set to 0. If the sprite is positioned so part of it is outside the coordinates of the display,
/// it wraps around to the opposite side of the screen.
/// A sprite is 8 bits of length and n bits of height
inline fn opcodeDRW() void {
    const X = extract(0xF00);
    const Y = extract(0xF0);
    const N = extract(0xF);
    const sx = cpu.V[X];
    const sy = cpu.V[Y];

    verboseOpcodeFmt("Drawing sprice at {d}, {d} with length {d}", .{ X, Y, N });
    for (0..N) |i| {
        const pixel = cpu.memory[cpu.I + i];
        inline for (0..8) |j| {
            if (pixel & (0b10000000 >> j) > 0) {
                cpu.V[0xF] = @max(cpu.V[0xF], cpu.graphicalBuffer[(j + sx) % 64 + ((i + sy) % 32) * 64]);
                cpu.graphicalBuffer[(j + sx) % 64 + ((i + sy) % 32) * 64] ^= 1;
            }
        }
    }
}

pub fn handleOpcode(_cpu: *CPU, _opcode: u16) void {
    cpu = _cpu;
    opcode = _opcode;

    cpu.PC += 2;
    switch (extract(0xF000)) {
        0x0 => switch (opcode & 0x00FF) {
            0xE0 => opcodeCLS(),
            0xEE => opcodeRET(),
            else => opcodeUnknown(),
        },
        0x1 => opcodeJMP(),
        0x2 => opcodeCALL(),
        0x3 => opcodeSKPEQ(),
        0x4 => opcodeSKPNEQ(),
        0x5 => opcodeSKPEQV(),
        0x6 => opcodeMOV(),
        0x7 => opcodeADD(),
        0x8 => switch (extract(0xF)) {
            0x0 => opcodeMOVV(),
            0x1 => opcodeOR(),
            0x2 => opcodeADDV(),
            0x3 => opcodeXOR(),
            0x4 => opcodeADDVC(),
            0x5 => opcodeSUBVC(),
            0x6 => opcodeRSHIFT(),
            0x7 => opcodeSUBYVC(),
            0xE => opcodeLSHIFT(),
            else => opcodeUnknown(),
        },
        0x9 => opcodeSKPNEQV(),
        0xA => opcodeMOVI(),
        0xB => opcodeJMPO(),
        0xC => opcodeRAND(),
        0xD => opcodeDRW(),
        else => opcodeUnknown(),
    }
}
