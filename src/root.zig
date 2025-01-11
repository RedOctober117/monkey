const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const EnumMap = std.enums.EnumMap;
const ascii = std.ascii;

pub const Lexer = struct {
    const Self = @This();
    const char = u8;

    /// Represents the different Token types.
    pub const TokenTypeTag = enum { illegal, eof, bind, plus, comma, semicolon, lparen, rparen, lbrace, rbrace, function, let, expression };

    /// Attaches a payload to each Token tag type as appropriate.
    pub const TokenType = union(TokenTypeTag) {
        illegal: char,
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
        expression: []const char,
    };

    /// A token, its type, its payload if relevent, and its position.
    pub const Token = struct {
        token_type: TokenType,
        position: char,
    };

    /// The state of the lexer, as determined by each character in the input string.
    const State = enum {
        expression,
        operator,
        whitespace,
        illegal,
    };

    output: ArrayList(Token),
    state: State,
    input: []const char,
    allocator: Allocator,

    /// Takes ownership of a `toOwnedSlice` of chars, freeing them and the output with `.free()`.
    pub fn init(input: *ArrayList(char), alloc: Allocator) Allocator.Error!Self {
        return .{
            .state = State.illegal,
            .input = try input.toOwnedSlice(),
            .output = ArrayList(Token).init(alloc),
            .allocator = alloc,
        };
    }

    /// Frees the output ArrayList and the input Slice.
    pub fn deinit(self: *Self) void {
        self.output.deinit();
        self.allocator.free(self.input);
    }

    fn match_expression(input: []const char) TokenType {
        if (std.mem.eql(char, input, "function")) {
            return TokenType.function;
        } else if (std.mem.eql(char, input, "let")) {
            return TokenType.let;
        } else {
            return TokenType{ .expression = input };
        }
    }

    fn change_state(self: *Self, input: char) void {
        switch (input) {
            '=', '+', ',', ';', '(', ')', '{', '}' => self.state = State.operator,
            else => {
                if (ascii.isWhitespace(input)) {
                    self.state = State.whitespace;
                } else if (ascii.isAlphanumeric(input)) {
                    self.state = State.expression;
                } else {
                    self.state = State.illegal;
                }
            },
        }
    }

    fn match_operator(input: char) TokenType {
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

    fn parse_buffer(self: *Self, word: []const char, index: char) Allocator.Error!void {
        if (word.len > 0) {
            const expression_type = match_expression(word);
            try self.output.append(.{
                .token_type = expression_type,
                .position = @intCast(index - word.len),
            });
        }
    }

    /// Produces a slice of Tokens, giving ownership to the caller. Can fail.
    pub fn tokenize(self: *Self) ![]Token {
        var buffer: ArrayList(char) = ArrayList(char).init(self.allocator);
        defer buffer.deinit();

        for (self.input, 0..self.input.len) |current_char, index| {
            if (!ascii.isASCII(current_char)) {
                return error.InvalidASCII;
            }

            const cast_index: char = @intCast(index);
            self.change_state(current_char);
            try switch (self.state) {
                State.whitespace => {
                    const buff = try buffer.toOwnedSlice();
                    defer self.allocator.free(buff);

                    try self.parse_buffer(buff, cast_index);
                },
                State.expression => buffer.append(current_char),
                State.illegal => {
                    const buff = try buffer.toOwnedSlice();
                    defer self.allocator.free(buff);

                    try self.parse_buffer(buff, cast_index);
                    try self.output.append(.{ .token_type = TokenType{ .illegal = current_char }, .position = cast_index });
                },
                State.operator => {
                    const buff = try buffer.toOwnedSlice();
                    defer self.allocator.free(buff);

                    try self.parse_buffer(buff, cast_index);
                    try self.output.append(.{ .token_type = match_operator(current_char), .position = cast_index });
                },
            };
        }

        const cast_index: char = @intCast(self.input.len);
        const buff = try buffer.toOwnedSlice();

        defer self.allocator.free(buff);

        try self.parse_buffer(buff, cast_index);
        try self.output.append(.{
            .token_type = TokenType.eof,
            .position = cast_index,
        });
        return self.output.toOwnedSlice();
    }
};
