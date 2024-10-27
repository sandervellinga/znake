const std = @import("std");
const snake = @import("snake.zig");
const global = @import("../objects/global.zig");

const Allocator = std.mem.Allocator;
const WallList = std.ArrayList(Wall);

const Snake = snake.Snake;
const KeyPress = global.KeyPress;
const Fruit = struct { row: u16, col: u16 };

pub const GameState = struct {
    height: u16,
    width: u16,
    allocator: Allocator,
    snake: Snake,
    running: bool = true,
    walls: WallList,
    fruit: Fruit,

    pub fn init(allocator: Allocator, height: u16, width: u16) !GameState {
        std.debug.print("Gamestate::init\n", .{});

        return .{
            .height = height,
            .width = width,
            .running = true,
            .allocator = allocator,
            .snake = try Snake.init(allocator, 18, 1, height, width),
            .walls = try setWalls(allocator, height, width),
            .fruit = Fruit{ .row = 3, .col = 50 },
        };
    }

    pub fn restart(self: *GameState) !void {
        // Delete old state
        self.walls.deinit();
        self.snake.deinit();

        self.snake = try Snake.init(self.allocator, 18, 1, self.height, self.width);
        self.walls = try setWalls(self.allocator, self.height, self.width);
        self.fruit = Fruit{ .row = 3, .col = 50 };
        self.running = true;
    }

    pub fn deinit(self: *GameState) void {
        self.running = false;
        std.debug.print("Running deinit", .{});
        self.walls.deinit();
        self.snake.deinit();
    }

    pub fn update(self: *GameState, input: KeyPress) !void {
        const nextMove = self.snake.nextMove(input); // always set direction
        if (self.snake.timeToMove()) {
            var blocked = false;
            for (self.walls.items) |wall| {
                if (wall.x == nextMove[0] and wall.y == nextMove[1]) {
                    blocked = true;
                    self.running = false;
                    break;
                }
            }
            for (self.snake.snakeparts.items) |snakepart| {
                if (snakepart.x == nextMove[0] and snakepart.y == nextMove[1]) {
                    blocked = true;
                    self.running = false;
                    break;
                }
            }

            if (self.fruit.col == nextMove[0] and self.fruit.row == nextMove[1]) {
                try self.snake.grow();
                try self.snake.grow();
                try self.snake.grow();
                try self.setFruit();
            }

            if (blocked == false) {
                try self.snake.move(nextMove[0], nextMove[1]);
            }
        }
    }

    fn setFruit(self: *GameState) !void {
        self.fruit.row = try getRandomInt(self.height - 7);

        const col = try getRandomInt(self.width - 4);
        if (@mod(col, 2) == 0) {
            self.fruit.col = col;
        } else {
            self.fruit.col = col + 1;
        }
    }

    fn getRandomInt(max: u16) !u16 {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        var random = std.Random.DefaultPrng.init(seed);
        return random.random().uintAtMost(u16, max) + 2;
    }

    fn setWalls(allocator: Allocator, height: u16, width: u16) !WallList {
        var walls = WallList.init(allocator);

        for (2..width - 2) |pos_x| {
            try walls.append(Wall{ .x = @intCast(pos_x), .y = 0 }); // top wall without side
            try walls.append(Wall{ .x = @intCast(pos_x), .y = height - 1 }); // bottom wall without side
        }

        for (0..height) |pos_y| {
            // left wall from top to bottom and two chars thick
            try walls.append(Wall{ .x = 0, .y = @intCast(pos_y) });
            try walls.append(Wall{ .x = 1, .y = @intCast(pos_y) });
            // right wall from top to bottom and two chars thick
            try walls.append(Wall{ .x = width - 1, .y = @intCast(pos_y) });
            try walls.append(Wall{ .x = width - 2, .y = @intCast(pos_y) });
        }

        return walls;
    }
};

pub const Wall = struct {
    x: u16,
    y: u16,
};

const testing = std.testing;
test "memleak" {
    var gs = try GameState.init(testing.allocator, 100, 100);
    defer gs.deinit();
}
