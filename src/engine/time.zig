const std = @import("std");

// 1 second =   1_000           milliseconds
//              1_000_000       microseconds
//              1_000_000_000   nanoseconds

pub const Time = struct {
    lastTime: i128,
    createTime: i128,

    pub fn init() Time {
        const time = std.time.nanoTimestamp();
        return .{
            .lastTime = time,
            .createTime = time,
        };
    }

    pub fn reset(self: *Time) void {
        self.lastTime = std.time.nanoTimestamp();
    }

    pub fn sinceLastTime(self: *Time) i128 {
        return std.time.nanoTimestamp() - self.lastTime;
    }

    pub fn totalTime(self: *Time) i128 {
        return std.time.nanoTimestamp() - self.createTime;
    }
};
