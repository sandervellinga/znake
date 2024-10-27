const std = @import("std");
const engine = @import("engine/engine.zig");
const global = @import("objects/global.zig");
const debug = std.debug;

const tui = engine.tui;
const Time = engine.time.Time;
const KeyPress = global.KeyPress;
const GameState = engine.gamestate.GameState;
const Renderer = engine.renderer.Renderer;

pub fn main() !void {
    try tui.init();
    defer tui.deinit() catch {};

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const fps: u64 = 30;
    var renderer = try Renderer.init(allocator, tui.size.height, tui.size.width);
    defer renderer.deinit();

    std.debug.print("MAIN::starting...\n", .{});
    var gs = try GameState.init(allocator, engine.tui.size.height, engine.tui.size.width);
    defer gs.deinit();

    try gs.snake.grow();
    try gs.snake.grow();
    try gs.snake.grow();

    var input: KeyPress = undefined;

    var time = Time.init();
    try tui.clearScreen();
    while (true) {
        time.reset();
        // INPUT PART
        input = try tui.getInput();
        if (input == .Q) {
            break;
        } else if (gs.running == false and input == .Space) {
            try gs.restart();
            try renderer.reset();
            try tui.clearScreen();
            try gs.snake.grow();
            try gs.snake.grow();
            try gs.snake.grow();
        }

        // GAME LOOP
        try gs.update(input);

        // OUTPUT PART
        if (gs.running) {
            try renderer.render(&gs);
        } else {
            try renderer.overlayText("YOU DIED! Press space to restart...");
        }

        // FINISH UP
        std.time.sleep(@intCast(@divFloor(1_000_000_000, fps) - time.sinceLastTime()));
        std.debug.print(" fps: {d}                ", .{@divFloor(1_000_000_000, time.sinceLastTime())});
    }

    try tui.clearScreen();
    var buf: [50]u8 = undefined;
    const text = try std.fmt.bufPrint(&buf, "You have played: {d} seconds.\n", .{@divFloor(time.totalTime(), 1_000_000_000)});
    try renderer.overlayText(text);
    std.time.sleep(2_000_000_000);
}
