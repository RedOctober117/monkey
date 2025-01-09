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

    read_position: u8, // current char being read
    next_position: u8, // location of next read
    input: []const u8,
    output: ArrayList(Token),
    allocator: Allocator,

    pub fn init(input: []const u8, alloc: Allocator) Self {
        return .{
            .read_position = 0,
            .next_position = 1,
            .input = input,
            .output = ArrayList(Token).init(alloc),
            .allocator = alloc,
        };
    }

    pub fn free(self: *Self) void {
        self.output.deinit();
    }

    fn has_next(self: Self) bool {
        return self.next_position <= self.input.len;
    }

    fn next(self: *Self) u8 {
        const next_char = self.input[self.read_position];
        self.next_position += 1;
        return next_char;
    }

    fn peak(self: Self) ?u8 {
        if (self.has_next()) {
            return self.input[self.next_position];
        } else {
            return null;
        }
    }

    fn parse_number_literal(self: *Self) Token {
        const start_idx: u8 = self.read_position;
        while (self.has_next()) {
            switch (self.next()) {
                48...57 => {
                    self.read_position += 1;
                },
                else => break,
            }
        }

        return .{
            .token_type = TokenType{ .int = self.input[start_idx..self.read_position] },
            .position = start_idx,
        };
    }

    fn parse_string_literal(self: *Self) Token {
        const start_idx: u8 = self.read_position;
        while (self.has_next()) {
            switch (self.next()) {
                'A'...'Z', 'a'...'z' => {
                    self.read_position += 1;
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

    pub fn tokenize(self: *Self) ![]Token {
        while (self.has_next()) {
            const current_char = self.next();
            switch (current_char) {
                '=' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .assign = '=' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                '+' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .plus = '+' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                ',' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .comma = ',' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                ';' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .semicolon = ';' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                '(' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .lparen = '(' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                ')' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .rparen = ')' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                '{' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .lbrace = '{' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                '}' => {
                    try self.output.append(.{
                        .token_type = TokenType{ .rbrace = '}' },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
                'A'...'Z', 'a'...'z' => try self.output.append(self.parse_string_literal()),
                48...57 => try self.output.append(self.parse_number_literal()),
                ' ', '\t', '\n', '\r' => self.read_position += 1,
                else => {
                    try self.output.append(.{
                        .token_type = TokenType{ .illegal = self.input[self.read_position] },
                        .position = self.read_position,
                    });
                    self.read_position += 1;
                },
            }
        }
        self.read_position += 1;
        try self.output.append(.{
            .token_type = TokenType.eof,
            .position = self.read_position,
        });
        return self.output.toOwnedSlice();
    }
};
