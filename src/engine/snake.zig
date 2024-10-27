const std = @import("std");
const time = @import("time.zig");
const global = @import("../objects/global.zig");

const Time = time.Time;
const Allocator = std.mem.Allocator;

const KeyPress = global.KeyPress;
const SnakePartList = std.ArrayList(SnakePart);

const Direction = enum { Up, Down, Right, Left };

pub const Snake = struct {
    snakeparts: SnakePartList,
    direction: Direction = .Right,
    time: Time,
    // temp fix to keep snake in current window, must be moved to gamestate
    height: u16,
    width: u16,

    pub fn init(allocator: Allocator, x: u16, y: u16, height: u16, width: u16) !Snake {
        std.debug.print("SNAKE::init\n", .{});

        var snakeparts = SnakePartList.init(allocator);
        const head = SnakePart{ .name = "head", .x = x, .y = y };
        const middle = SnakePart{ .name = "middle", .x = x - 2, .y = y };
        const tail = SnakePart{ .name = "tail", .x = x - 4, .y = y };

        try snakeparts.append(head);
        try snakeparts.append(middle);
        try snakeparts.append(tail);

        return .{
            .time = Time.init(),
            .snakeparts = snakeparts,
            .height = height,
            .width = width,
        };
    }

    pub fn deinit(self: *Snake) void {
        self.snakeparts.deinit();
    }

    pub fn timeToMove(self: *Snake) bool {
        if (self.time.sinceLastTime() >= 70_000_000) {
            return true;
        }
        return false;
    }

    pub fn nextMove(self: *Snake, input: KeyPress) [2]u16 {
        if (input == .UpArrow) {
            self.direction = if (self.direction != .Down) .Up else .Down;
        } else if (input == .DownArrow) {
            self.direction = if (self.direction != .Up) .Down else .Up;
        } else if (input == .RightArrow) {
            self.direction = if (self.direction != .Left) .Right else .Left;
        } else if (input == .LeftArrow) {
            self.direction = if (self.direction != .Right) .Left else .Right;
        }

        var x = self.snakeparts.items[0].x;
        var y = self.snakeparts.items[0].y;

        switch (self.direction) {
            .Up => y -|= 1,
            .Down => y = @min(y + 1, self.height),
            .Right => x = @min(x + 2, self.width - 2),
            .Left => x -|= 2,
        }
        return .{ x, y };
    }

    pub fn move(self: *Snake, x: u16, y: u16) !void {
        var tailToHead = self.snakeparts.pop();
        tailToHead.x = x;
        tailToHead.y = y;
        try self.snakeparts.insert(0, tailToHead);
        self.time.reset();
    }

    pub fn grow(self: *Snake) !void {
        // Put new tail on current tail position, it doesn't really matter
        // as we do move() right after grow() which moved the tail to head
        const x = self.snakeparts.items[self.snakeparts.items.len - 1].x;
        const y = self.snakeparts.items[self.snakeparts.items.len - 1].y;
        try self.snakeparts.append(SnakePart{ .name = "newPart", .x = x, .y = y });
    }

    pub fn print(self: *Snake) void {
        for (self.snakeparts.items) |snakepart| {
            std.debug.print("Snakepart: name:{s}, x:{d}, y:{d}\n", .{ snakepart.name, snakepart.x, snakepart.y });
        }
        std.debug.print("\n", .{});
    }
};

pub const SnakePart = struct {
    x: u16,
    y: u16,
    name: []const u8,
};

// const testing = std.testing;
// test "Snake init" {
//     const startX = 2;
//     const startY = 0;
//     var snake = try Snake.init(testing.allocator, startX, startY, 100, 100);
//     defer snake.deinit();
//
//     snake.print();
//
//     try snake.move(.Right);
//     snake.print();
//
//     try snake.move(.Right);
//     snake.print();
//
//     try snake.move(.Right);
//     snake.print();
//
//     try snake.move(.Down);
//     snake.print();
//
//     try testing.expectEqual(snake.snakeparts.items.len, 3);
// }
