const std = @import("std");
const gamestate = @import("game-state.zig");
const Allocator = std.mem.Allocator;

const GameState = gamestate.GameState;
const BufferedWriter = std.io.BufferedWriter(100000, @TypeOf(std.io.getStdOut().writer()));

const CellType = enum { Wall, Snake, Fruit, Empty };
const Coordinate = struct { row: u16, col: u16 };
const Cell = struct { type: CellType, coordinate: Coordinate };

pub const Renderer = struct {
    height: u16,
    width: u16,
    allocator: Allocator,
    buffer: BufferedWriter,
    previousFrame: []Cell,

    pub fn init(allocator: Allocator, height: u16, width: u16) !Renderer {
        return .{
            .height = height,
            .width = width,
            .allocator = allocator,
            .buffer = BufferedWriter{ .unbuffered_writer = std.io.getStdOut().writer() },
            .previousFrame = try emptyFrame(allocator, height, width), // initialize with empty frame

        };
    }

    pub fn deinit(self: *Renderer) void {
        self.allocator.free(self.previousFrame);
    }

    pub fn reset(self: *Renderer) !void {
        const frame = try emptyFrame(self.allocator, self.height, self.width);
        defer self.allocator.free(frame);
        @memcpy(self.previousFrame, frame);
    }

    pub fn overlayText(self: *Renderer, text: []const u8) !void {
        const writer = self.buffer.writer();

        const middleOfScreen = self.height / 2;

        //        try moveCursor(writer, middleOfScreen - 1, 0);

        try moveCursor(writer, middleOfScreen, (self.width / 2) - 17);
        try writer.print("\x1B[0;41m{s}\x1B[0m", .{text});
        try self.buffer.flush();
    }

    pub fn render(self: *Renderer, gs: *GameState) !void {
        // Start with new empty frame
        var frame = try self.allocator.alloc(Cell, self.width * self.height);
        defer self.allocator.free(frame);

        for (0..self.width * self.height) |number| {
            const coordinate = convertNumberToRowCol(self.width, @intCast(number));
            frame[number] = Cell{ .type = CellType.Empty, .coordinate = coordinate };
        }

        // Add walls
        for (gs.walls.items) |wall| {
            const number = convertRowColToNumber(self.width, wall.y, wall.x);
            frame[number] = Cell{ .type = CellType.Wall, .coordinate = Coordinate{ .row = wall.y, .col = wall.x } };
        }

        // Add snake
        for (gs.snake.snakeparts.items) |snakepart| {
            const number = convertRowColToNumber(self.width, snakepart.y, snakepart.x);
            frame[number] = Cell{ .type = CellType.Snake, .coordinate = Coordinate{ .row = snakepart.y, .col = snakepart.x } };
        }

        // Add fruit
        const number = convertRowColToNumber(self.width, gs.fruit.row, gs.fruit.col);
        frame[number] = Cell{ .type = CellType.Fruit, .coordinate = Coordinate{ .row = gs.fruit.row, .col = gs.fruit.col } };

        const writer = self.buffer.writer();

        try moveCursor(writer, 0, 0);
        for (frame, self.previousFrame) |curCell, prevCell| {
            if (curCell.type != prevCell.type) {
                try moveCursor(writer, curCell.coordinate.row, curCell.coordinate.col);
                switch (curCell.type) {
                    .Empty => try writer.print("  ", .{}),
                    .Wall => try writer.print("\x1B[0;43m \x1B[0m", .{}),
                    .Snake => try writer.print("[]", .{}),
                    .Fruit => try writer.print("xx", .{}),
                }
            }
        }

        @memcpy(self.previousFrame, frame);

        try moveCursor(writer, self.height + 1, 3);
        try writer.print("Buffer size: {d}, Buffer usage: {d}, Heigth: {d}, Width: {d}, X: {d}, Y: {d}           ", .{ self.buffer.buf.len, self.buffer.end, self.height, self.width, gs.snake.snakeparts.items[0].x, gs.snake.snakeparts.items[0].y });

        try self.buffer.flush();
    }

    fn emptyFrame(allocator: Allocator, height: u16, width: u16) ![]Cell {
        var frame = try allocator.alloc(Cell, height * width);
        for (0..width * height) |number| {
            const coordinate = convertNumberToRowCol(width, @intCast(number));
            frame[number] = Cell{ .type = CellType.Empty, .coordinate = coordinate };
        }

        return frame;
    }

    fn moveCursor(writer: anytype, row: u16, col: u16) !void {
        try writer.print("\x1B[{};{}H", .{ row + 1, col + 1 });
    }
};

fn convertNumberToRowCol(width: u16, number: u16) Coordinate {
    const row = @divFloor(number, width);
    const col = @mod(number, width);

    // std.debug.print("Number {d} represents: row {d} and col {d}\n", .{ number, row, col });

    return Coordinate{ .row = row, .col = col };
}

fn convertRowColToNumber(width: u16, row: u16, col: u16) u16 {
    const number = row * width + col;

    // std.debug.print("Row {d} and col {d} is represented by the number {d}\n", .{ row, col, number });

    return number;
}

const testing = std.testing;
test "Coordinates" {
    const row: u16 = 4;
    const col: u16 = 3;
    const number: u16 = 23;

    const generatedNumber = convertRowColToNumber(5, row, col);
    try testing.expectEqual(number, generatedNumber);

    const generatedRowCol = convertNumberToRowCol(5, number);

    try testing.expectEqual(row, generatedRowCol.row);
    try testing.expectEqual(col, generatedRowCol.col);
}

test "render" {
    var gs = try GameState.init(testing.allocator, 50, 50);
    defer gs.deinit();

    var renderer = try Renderer.init(testing.allocator, 50, 50);
    defer renderer.deinit();

    try renderer.render(&gs);
    try renderer.reset();
}
