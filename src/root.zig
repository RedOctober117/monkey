const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const fields = std.meta.fields;

const TokenTypeTag = enum { illegal, eof, ident, int, assign, plus, comma, semicolon, lparen, rparen, lbrace, rbrace, function, let };

const TokenType = union(TokenTypeTag) {
    illegal: u8,
    eof: void,
    ident: []const u8,
    int: []const u8,
    assign: u8,
    plus: u8,
    comma: u8,
    semicolon: u8,
    lparen: u8,
    rparen: u8,
    lbrace: u8,
    rbrace: u8,
    function: void,
    let: void,
};

const Token = struct {
    token_type: TokenType,
    position: u8,
};

pub const Lexer = struct {
    const Self = @This();

    const State = enum {
        init,
        word,
        number,
        symbol,
    };

    state: State,
    read_position: u8, // current char being read
    input: []const u8,
    output: ArrayList(Token),
    allocator: Allocator,

    pub fn init(input: []const u8, alloc: Allocator) Self {
        return .{
            .state = State.init,
            .read_position = 0,
            .input = input,
            .output = ArrayList(Token).init(alloc),
            .allocator = alloc,
        };
    }

    pub fn free(self: *Self) void {
        self.output.deinit();
    }

    fn has_next(self: Self) bool {
        return self.read_position < self.input.len;
    }

    fn next(self: *Self) u8 {
        const read_char = self.input[self.read_position];
        self.read_position += 1;
        return read_char;
    }

    fn advance(self: *Self) void {
        self.read_position += 1;
    }

    fn peak(self: Self) ?u8 {
        if (self.has_next()) {
            return self.input[self.read_position + 1];
        } else {
            return null;
        }
    }

    fn parse_number_literal(self: *Self) Token {
        const start_idx: u8 = self.read_position;
        while (self.has_next()) {
            switch (self.next()) {
                '0'...'9' => {
                    self.advance();
                },
                else => {
                    self.advance();
                    break;
                },
            }
        }

        return .{
            .token_type = TokenType{ .int = self.input[start_idx .. self.read_position - 1] },
            .position = start_idx,
        };
    }

    fn parse_string_literal(self: *Self) Token {
        const start_idx: u8 = self.read_position;
        while (self.has_next()) {
            switch (self.next()) {
                'A'...'Z', 'a'...'z' => {
                    continue;
                },
                else => break,
            }
        }

        var token = TokenType{ .ident = self.input[start_idx..self.read_position] };

        if (std.mem.eql(u8, token.ident, "function")) {
            token = TokenType.function;
        } else if (std.mem.eql(u8, token.ident, "let")) {
            token = TokenType.let;
        }

        return .{
            .token_type = token,
            .position = start_idx,
        };
    }

    fn is_ascii_letter(token: u8) bool {
        return switch (token) {
            'A'...'Z', 'a'...'z' => true,
            else => false,
        };
    }

    fn is_ascii_number(token: u8) bool {
        return switch (token) {
            '0'...'9' => true,
            else => false,
        };
    }

    fn is_ascii_whitespace(token: u8) bool {
        return switch (token) {
            ' ', '\t', '\n', '\r' => true,
            else => false,
        };
    }

    pub fn tokenize(self: *Self) ![]Token {
        for (self.input) |current_char| {
            switch (self.state) {
                State.init => {
                    if (is_ascii_letter(current_char)) {
                        self.state = State.word;
                    }
                },
                State.word => {
                    if (is_ascii_letter(current_char)) {
                        self.state = State.word;
                    }
                },
            }
            switch (current_char) {
                '=' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .assign = '=' },
                        .position = self.read_position,
                    });
                },
                '+' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .plus = '+' },
                        .position = self.read_position,
                    });
                },
                ',' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .comma = ',' },
                        .position = self.read_position,
                    });
                },
                ';' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .semicolon = ';' },
                        .position = self.read_position,
                    });
                },
                '(' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .lparen = '(' },
                        .position = self.read_position,
                    });
                },
                ')' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .rparen = ')' },
                        .position = self.read_position,
                    });
                },
                '{' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .lbrace = '{' },
                        .position = self.read_position,
                    });
                },
                '}' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .rbrace = '}' },
                        .position = self.read_position,
                    });
                },
                'A'...'Z', 'a'...'z' => try self.output.append(self.parse_string_literal()),
                '0'...'9' => try self.output.append(self.parse_number_literal()),
                ' ', '\t', '\n', '\r' => continue,
                else => {
                    try self.output.append(.{
                        .token_type = TokenType{ .illegal = self.input[self.read_position] },
                        .position = self.read_position,
                    });
                },
            }
        }
        try self.output.append(.{
            .token_type = TokenType.eof,
            .position = self.read_position,
        });
        return self.output.toOwnedSlice();
    }
};
