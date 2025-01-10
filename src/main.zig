const std = @import("std");
const root = @import("root.zig");
const general_allocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;

pub fn main() !void {
    var gpa = general_allocator(.{}){};

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var user_input: ArrayList(u8) = ArrayList(u8).init(gpa.allocator());

    try stdout.print("Enter: ", .{});
    try stdin.streamUntilDelimiter(user_input.writer(), '\n', null);

    var lexer = try root.Lexer.init(&user_input, gpa.allocator());
    defer lexer.deinit();

    const result = try lexer.tokenize();

    for (result) |res| {
        std.debug.print("{}\n", .{res});
    }
}
