const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const EnumMap = std.enums.EnumMap;

pub const Lexer = struct {
    const Self = @This();

    /// Represents the different Token types.
    const TokenTypeTag = enum { illegal, eof, bind, plus, comma, semicolon, lparen, rparen, lbrace, rbrace, function, let, expression };

    /// Attaches a payload to each Token tag type as appropriate.
    const TokenType = union(TokenTypeTag) {
        illegal: u8,
        eof: void,
        bind: void,
        plus: void,
        comma: void,
        semicolon: void,
        lparen: void,
        rparen: void,
        lbrace: void,
        rbrace: void,
        function: void,
        let: void,
        expression: []const u8,
    };

    /// A token, its type, its payload if relevent, and its position.
    const Token = struct {
        token_type: TokenType,
        position: u8,
    };

    /// The state of the lexer, as determined by each character in the input string.
    const State = enum {
        expression,
        operator,
        whitespace,
        illegal,
    };

    state: State,
    input: []const u8,
    output: ArrayList(Token),
    allocator: Allocator,

    pub fn init(input: *ArrayList(u8), alloc: Allocator) !Self {
        return .{
            .state = State.illegal,
            .input = try input.toOwnedSlice(),
            .output = ArrayList(Token).init(alloc),
            .allocator = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit();
    }

    fn match_expression(input: []const u8) TokenType {
        if (std.mem.eql(u8, input, "function")) {
            return TokenType.function;
        } else if (std.mem.eql(u8, input, "let")) {
            return TokenType.let;
        } else {
            return TokenType{ .expression = input };
        }
    }

    fn change_state(self: *Self, input: u8) void {
        self.state = switch (input) {
            'A'...'Z',
            'a'...'z',
            '_',
            '0'...'9',
            => State.expression,
            ' ', '\t', '\n', '\r' => State.whitespace,
            '=', '+', ',', ';', '(', ')', '{', '}' => State.operator,
            else => State.illegal,
        };
    }

    fn match_operator(input: u8) TokenType {
        return switch (input) {
            '=' => TokenType.bind,
            '+' => TokenType.plus,
            ',' => TokenType.comma,
            ';' => TokenType.semicolon,
            '(' => TokenType.lparen,
            ')' => TokenType.rparen,
            '{' => TokenType.lbrace,
            '}' => TokenType.rbrace,
            else => TokenType{ .illegal = input },
        };
    }

    fn parse_buffer(self: *Self, word: []const u8, index: u8) !void {
        if (word.len > 0) {
            const expression_type = match_expression(word);
            try self.output.append(.{
                .token_type = expression_type,
                .position = @intCast(index - word.len),
            });
        }
    }

    pub fn tokenize(self: *Self) ![]Token {
        var buffer: ArrayList(u8) = ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        for (self.input, 0..self.input.len) |current_char, index| {
            const cast_index: u8 = @intCast(index);
            self.change_state(current_char);
            try switch (self.state) {
                State.whitespace => {
                    try self.parse_buffer(try buffer.toOwnedSlice(), cast_index);
                },
                State.expression => buffer.append(current_char),
                State.illegal => {
                    try self.parse_buffer(try buffer.toOwnedSlice(), cast_index);
                    try self.output.append(.{ .token_type = TokenType{ .illegal = current_char }, .position = cast_index });
                },
                State.operator => {
                    try self.parse_buffer(try buffer.toOwnedSlice(), cast_index);
                    try self.output.append(.{ .token_type = match_operator(current_char), .position = cast_index });
                },
            };
        }
        const cast_index: u8 = @intCast(self.input.len);
        try self.parse_buffer(try buffer.toOwnedSlice(), cast_index);
        try self.output.append(.{
            .token_type = TokenType.eof,
            .position = cast_index,
        });
        return self.output.toOwnedSlice();
    }
};
