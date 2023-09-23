const std = @import("std");

const print = std.debug.print;

pub const CPU = struct {
    const Self = @This();

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
        print("cycle\n", .{});
    }

    pub fn clocked_cycle(self: *Self, comptime clock: usize) !void {
        const millis = std.time.milliTimestamp();
        if (millis - self.lastCycle >= 1000/clock) {
            self.lastCycle = millis;
            try self.cycle();
        }

    }
};
