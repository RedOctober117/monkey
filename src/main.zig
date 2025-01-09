const std = @import("std");
const root = @import("root.zig");
const general_allocator = std.heap.GeneralPurposeAllocator;

pub fn main() !void {
    var gpa = general_allocator(.{}){};

    const test_str = "let x = 10;";
    var lexer = root.Lexer.init(test_str, gpa.allocator());
    defer lexer.free();
    const result = try lexer.tokenize();
    std.debug.print("testing: {s}\n", .{test_str});
    for (result) |res| {
        std.debug.print("{}\n", .{res});
    }
    std.debug.print("{c}", .{114});
}
