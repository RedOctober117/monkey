const std = @import("std");
const root = @import("root.zig");
const test_allocator = std.testing.allocator;
const testing = std.testing;
const general_allocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const TokenType = root.Lexer.TokenType;
const Token = root.Lexer.Token;
const StaticStringMap = std.static_string_map.StaticStringMap;

pub fn main() !void {
    var gpa = general_allocator(.{}){};
    defer _ = gpa.deinit();
    defer _ = &gpa.detectLeaks();

    const allocator = gpa.allocator();

    // var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    // defer arena.deinit();

    // const stdin = std.io.getStdIn().reader();
    // const stdout = std.io.getStdOut().writer();

    // var user_input: ArrayList(u8) = ArrayList(u8).init(gpa.allocator());
    // defer user_input.deinit();

    // try stdout.print("Enter: ", .{});
    // try stdin.streamUntilDelimiter(user_input.writer(), '\n', null);

    // var lexer = try root.Lexer.init(&user_input, gpa.allocator());
    // defer lexer.deinit();

    var input = ArrayList(u8).init(allocator);

    try input.insertSlice(0, "LET A=0; LET B=1; PRINT A; 100 PRINT B; LET B=A+B; LET A=B-A; IF B<=1000 THEN GOTO 100; END");

    var lexer = try root.Lexer.init(&input, allocator);
    defer lexer.deinit();

    const result = try lexer.tokenize();

    for (result) |res| {
        // try stdout.print("{}\n", .{res});
        std.debug.print("{any}\n", .{res});
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
    try test_expr.appendSlice("LET x = 10;");

    var lexer = try root.Lexer.init(&test_expr, test_allocator);
    defer lexer.deinit();

    const result = try lexer.tokenize();

    // try testing.expectEqualSlices(Token, &expected_arr, result);
    for (result, expected_arr) |actual, expected| {
        try testing.expect(@intFromEnum(actual.token_type) == @intFromEnum(expected.token_type));
        try testing.expect(actual.position == expected.position);
    }
}

test "operator matching" {
    const expected_arr = [_]Token{
        Token{ .token_type = TokenType.gte, .position = 0 },
        Token{ .token_type = TokenType.lte, .position = 3 },
        Token{ .token_type = TokenType.ne, .position = 6 },
        Token{ .token_type = TokenType.lt, .position = 9 },
        Token{ .token_type = TokenType.gt, .position = 11 },
        Token{ .token_type = TokenType.bind, .position = 13 },
        Token{ .token_type = TokenType.plus, .position = 15 },
        Token{ .token_type = TokenType.eof, .position = 16 },
    };

    var test_expr: ArrayList(u8) = ArrayList(u8).init(test_allocator);
    try test_expr.appendSlice(">= <= <> < > = +");

    var lexer = try root.Lexer.init(&test_expr, test_allocator);
    defer lexer.deinit();

    const result = try lexer.tokenize();

    for (result, expected_arr) |actual, expected| {
        try testing.expect(@intFromEnum(actual.token_type) == @intFromEnum(expected.token_type));
        try testing.expect(actual.position == expected.position);
    }
}
