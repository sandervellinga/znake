const std = @import("std");
const global = @import("../objects/global.zig");

const os = std.posix;
const fs = std.fs;
const mem = std.mem;

const KeyPress = global.KeyPress;
pub var size: Size = undefined;
var cooked_termios: os.termios = undefined;
var raw: os.termios = undefined;
pub var tty: fs.File = undefined;

pub fn init() !void {
    tty = try fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });

    try uncook();

    size = try getSize();

    try os.sigaction(os.SIG.WINCH, &os.Sigaction{
        .handler = .{ .handler = handleSigWinch },
        .mask = os.empty_sigset,
        .flags = 0,
    }, null);
}

pub fn deinit() !void {
    // restore terminal
    cook() catch |err| {
        std.debug.print("There was an error", .{});
        return err;
    };

    tty.close();
}

fn handleSigWinch(_: c_int) callconv(.C) void {
    size = getSize() catch return;
    // render() catch return;
}

pub fn getInput() !KeyPress {
    // Should move this to its own thing
    var buffer: [1]u8 = undefined;
    _ = try tty.read(&buffer);

    if (buffer[0] == 'q') {
        return KeyPress.Q;
    } else if (buffer[0] == ' ') {
        return KeyPress.Space;
    } else if (buffer[0] == '\x1B') {
        var esc_buffer: [8]u8 = undefined;
        const esc_read = try tty.read(&esc_buffer);

        if (mem.eql(u8, esc_buffer[0..esc_read], "[A")) { // UP
            return .UpArrow;
        } else if (mem.eql(u8, esc_buffer[0..esc_read], "[B")) { // DOWN
            return .DownArrow;
        } else if (mem.eql(u8, esc_buffer[0..esc_read], "[C")) { // RIGHT
            return .RightArrow;
        } else if (mem.eql(u8, esc_buffer[0..esc_read], "[D")) { // LEFT
            return .LeftArrow;
        }
    }

    return .NotSupported;
}

pub fn clearScreen() !void {
    const writer = tty.writer();
    try clear(writer);
}

pub fn write(output: []const u8) !void {
    const writer = tty.writer();
    try writer.writeAll(output);
}

pub fn writeChar(char: []const u8, y: u16, x: u16) !void {
    const writer = tty.writer();
    try clear(writer); // Need this later
    try moveCursor(writer, y, x);
    try writer.writeAll(char);
}

fn writeLine(txt: []const u8, y: usize, width: usize, selected: bool) !void {
    const writer = tty.writer();
    if (selected) {
        try blueBackground(writer);
    } else {
        try attributeReset(writer);
    }
    try moveCursor(writer, y, 0);
    try writer.writeByteNTimes(' ', width - txt.len);
    try writer.writeAll(txt);
    try writer.writeByteNTimes(' ', width - txt.len);
}

fn uncook() !void {
    const writer = tty.writer();
    cooked_termios = try os.tcgetattr(tty.handle);
    errdefer cook() catch {};

    raw = cooked_termios;

    //   ECHO: Stop the terminal from displaying pressed keys.
    // ICANON: Disable canonical ("cooked") input mode. Allows us to read inputs
    //         byte-wise instead of line-wise.
    //   ISIG: Disable signals for Ctrl-C (SIGINT) and Ctrl-Z (SIGTSTP), so we
    //         can handle them as "normal" escape sequences.
    // IEXTEN: Disable input preprocessing. This allows us to handle Ctrl-V,
    //         which would otherwise be intercepted by some terminals.
    raw.lflag = os.system.tc_lflag_t{ .ECHO = false, .ICANON = false, .ISIG = false, .IEXTEN = false };

    //   IXON: Disable software control flow. This allows us to handle Ctrl-S
    //         and Ctrl-Q.
    //  ICRNL: Disable converting carriage returns to newlines. Allows us to
    //         handle Ctrl-J and Ctrl-M.
    // BRKINT: Disable converting sending SIGINT on break conditions. Likely has
    //         no effect on anything remotely modern.
    //  INPCK: Disable parity checking. Likely has no effect on anything
    //         remotely modern.
    // ISTRIP: Disable stripping the 8th bit of characters. Likely has no effect
    //         on anything remotely modern.
    raw.iflag = os.system.tc_iflag_t{ .IXON = false, .ICRNL = false, .BRKINT = false, .INPCK = false, .ISTRIP = false };

    // Disable output processing. Common output processing includes prefixing
    // newline with a carriage return.
    raw.oflag = os.system.tc_oflag_t{ .OPOST = false };

    raw.cc[@intFromEnum(os.V.TIME)] = 0;
    raw.cc[@intFromEnum(os.V.MIN)] = 0;
    try os.tcsetattr(tty.handle, .FLUSH, raw);

    try hideCursor(writer);
    try enterAlt(writer);
    try clear(writer);
}

fn cook() !void {
    const writer = tty.writer();
    try clear(writer);
    try leaveAlt(writer);
    try showCursor(writer);
    try attributeReset(writer);
    try os.tcsetattr(tty.handle, .FLUSH, cooked_termios);
}

fn moveCursor(writer: anytype, row: u16, col: u16) !void {
    _ = try writer.print("\x1B[{};{}H", .{ row + 1, col + 1 });
}

fn enterAlt(writer: anytype) !void {
    try writer.writeAll("\x1B[s"); // Save cursor position.
    try writer.writeAll("\x1B[?47h"); // Save screen.
    try writer.writeAll("\x1B[?1049h"); // Enable alternative buffer.
}

fn leaveAlt(writer: anytype) !void {
    try writer.writeAll("\x1B[?1049l"); // Disable alternative buffer.
    try writer.writeAll("\x1B[?47l"); // Restore screen.
    try writer.writeAll("\x1B[u"); // Restore cursor position.
}

fn hideCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[?25l");
}

fn showCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[?25h");
}

fn attributeReset(writer: anytype) !void {
    try writer.writeAll("\x1B[0m");
}

fn blueBackground(writer: anytype) !void {
    try writer.writeAll("\x1B[44m");
}

fn clear(writer: anytype) !void {
    try writer.writeAll("\x1B[2J");
}

const Size = struct { width: u16, height: u16 };

fn getSize() !Size {
    var win_size = mem.zeroes(os.system.winsize);
    const err = os.system.ioctl(tty.handle, os.system.T.IOCGWINSZ, @intFromPtr(&win_size));
    if (os.errno(err) != .SUCCESS) {
        return os.unexpectedErrno(@enumFromInt(err));
    }
    return Size{
        .height = win_size.ws_row - 3,
        .width = win_size.ws_col,
    };
}
