const std = @import("std");
const root = @import("root.zig");
const test_allocator = std.testing.allocator;
const testing = std.testing;
const general_allocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const TokenType = root.Lexer.TokenType;
const Token = root.Lexer.Token;

pub fn main() !void {
    var gpa = general_allocator(.{}){};

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var user_input: ArrayList(u8) = ArrayList(u8).init(gpa.allocator());
    defer user_input.deinit();

    try stdout.print("Enter: ", .{});
    try stdin.streamUntilDelimiter(user_input.writer(), '\n', null);

    var lexer = try root.Lexer.init(&user_input, gpa.allocator());
    defer lexer.deinit();

    const result = try lexer.tokenize();
    defer gpa.allocator().free(result);

    for (result) |res| {
        try stdout.print("{}\n", .{res});
    }
}

test "check mem leaks" {
    const expected_arr: [6]Token = .{
        Token{ .token_type = TokenType.let, .position = 0 },
        Token{ .token_type = TokenType{ .expression = &.{120} }, .position = 4 },
        Token{ .token_type = TokenType.bind, .position = 6 },
        Token{ .token_type = TokenType{ .expression = &.{ 49, 48 } }, .position = 8 },
        Token{ .token_type = TokenType.semicolon, .position = 10 },
        Token{ .token_type = TokenType.eof, .position = 11 },
    };

    var test_expr: ArrayList(u8) = ArrayList(u8).init(test_allocator);
    try test_expr.appendSlice("let x = 10;");

    var lexer = try root.Lexer.init(&test_expr, test_allocator);
    defer lexer.deinit();

    const result = try lexer.tokenize();
    defer test_allocator.free(result);

    for (result, expected_arr) |actual, expected| {
        try testing.expect(@intFromEnum(actual.token_type) == @intFromEnum(expected.token_type));
        try testing.expect(actual.position == expected.position);
    }
}
