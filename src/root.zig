const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const EnumMap = std.enums.EnumMap;
const ascii = std.ascii;
const StaticStringMap = std.static_string_map.StaticStringMap;

pub const Lexer = struct {
    const Self = @This();
    const char = u8;

    /// Attaches a payload to each Token tag type as appropriate.
    pub const TokenType = union(enum) {
        illegal: []const char,
        expression: []const char,
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
        if_: void,
        then: void,
        goto: void,
        end: void,
        print: void,
        lt: void,
        gt: void,
        ne: void,
        gte: void,
        lte: void,
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
    input: []char,
    arena: *ArenaAllocator,

    /// Takes ownership of a `toOwnedSlice` of chars, freeing them and the output with `.free()`.
    pub fn init(input: *ArrayList(char), alloc: Allocator) Allocator.Error!Self {
        const input_slice = try input.toOwnedSlice();
        defer alloc.free(input_slice);

        // this is a pointer to an arena allocator on the stack to preserve the allocator state
        const arena = try alloc.create(ArenaAllocator);
        const input_alloc = try alloc.dupe(u8, input_slice);

        errdefer alloc.destroy(arena);
        errdefer alloc.destroy(input_alloc);

        arena.* = ArenaAllocator.init(alloc);

        return .{
            .state = State.illegal,
            .input = input_alloc,
            .output = ArrayList(Token).init(arena.allocator()),
            .arena = arena,
        };
    }

    /// Frees the output ArrayList and the input Slice.
    pub fn deinit(self: *Self) void {
        const child_alloc = self.arena.child_allocator;
        self.arena.deinit();
        child_alloc.free(self.input);
        child_alloc.destroy(self.arena);
    }

    fn change_state(self: *Self, input: char) void {
        switch (input) {
            '=', '+', ',', ';', '(', ')', '{', '}', '<', '>' => self.state = State.operator,
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

    const expression_map = StaticStringMap(TokenType).initComptime(.{
        .{ "FUNCTION", TokenType.function },
        .{ "LET", TokenType.let },
        .{ "IF", TokenType.if_ },
        .{ "THEN", TokenType.then },
        .{ "GOTO", TokenType.goto },
        .{ "END", TokenType.end },
        .{ "PRINT", TokenType.print },
    });

    const operator_map = StaticStringMap(TokenType).initComptime(.{
        .{ "=", TokenType.bind },
        .{ "+", TokenType.plus },
        .{ ",", TokenType.comma },
        .{ ";", TokenType.semicolon },
        .{ "(", TokenType.lparen },
        .{ ")", TokenType.rparen },
        .{ "{", TokenType.lbrace },
        .{ "}", TokenType.rbrace },
        .{ "<", TokenType.lt },
        .{ ">", TokenType.gt },
        .{ "<>", TokenType.ne },
        .{ ">=", TokenType.gte },
        .{ "<=", TokenType.lte },
    });

    fn parse_expr_buffer(self: *Self, word: []const char, index: char) Allocator.Error!void {
        if (word.len > 0) {
            const expression_type = expression_map.get(word);
            try self.output.append(.{
                .token_type = if (expression_type != null) expression_type.? else TokenType{ .expression = word },
                .position = @intCast(index - word.len),
            });
        }
    }

    fn parse_opr_buffer(self: *Self, word: []const char, index: char) Allocator.Error!void {
        if (word.len > 0) {
            const operator_type = operator_map.get(word);
            try self.output.append(.{
                .token_type = if (operator_type != null) operator_type.? else TokenType{ .illegal = word },
                .position = @intCast(index - word.len),
            });
        }
    }

    /// Produces a slice of Tokens, giving ownership to the caller. Can fail.
    pub fn tokenize(self: *Self) ![]Token {
        var expression_buffer: ArrayList(char) = ArrayList(char).init(self.arena.allocator());
        var operator_buffer: ArrayList(char) = ArrayList(char).init(self.arena.allocator());
        defer expression_buffer.deinit();
        defer operator_buffer.deinit();

        for (self.input, 0..self.input.len) |current_char, index| {
            if (!ascii.isASCII(current_char)) {
                return error.InvalidASCII;
            }

            const cast_index: char = @intCast(index);
            self.change_state(current_char);
            switch (self.state) {
                // add expr and parse opr
                State.expression => {
                    try expression_buffer.append(current_char);

                    // remember, []T is a pointer to items T
                    const opr_buff = try self.arena.allocator().dupe(char, try operator_buffer.toOwnedSlice());
                    errdefer self.arena.allocator().free(opr_buff);

                    try self.parse_opr_buffer(opr_buff, cast_index);
                },

                // add opr and parse expr
                State.operator => {
                    try operator_buffer.append(current_char);

                    const expr_buff = try self.arena.allocator().dupe(char, try expression_buffer.toOwnedSlice());
                    errdefer self.arena.allocator().free(expr_buff);
                    // defer self.allocator.free(expr_buff);

                    try self.parse_expr_buffer(expr_buff, cast_index);
                },

                // parse expr and opr=
                State.whitespace => {
                    const expr_buff = try self.arena.allocator().dupe(char, try expression_buffer.toOwnedSlice());
                    const opr_buff = try self.arena.allocator().dupe(char, try operator_buffer.toOwnedSlice());
                    errdefer self.arena.allocator().free(expr_buff);
                    errdefer self.arena.allocator().free(opr_buff);

                    try self.parse_expr_buffer(expr_buff, cast_index);
                    try self.parse_opr_buffer(opr_buff, cast_index);
                },

                // parse expr and opr, add illegal token
                State.illegal => {
                    const expr_buff = try self.arena.allocator().dupe(char, try expression_buffer.toOwnedSlice());
                    const opr_buff = try self.arena.allocator().dupe(char, try operator_buffer.toOwnedSlice());
                    errdefer self.arena.allocator().free(expr_buff);
                    errdefer self.arena.allocator().free(opr_buff);

                    try self.parse_expr_buffer(expr_buff, cast_index);
                    try self.parse_opr_buffer(opr_buff, cast_index);

                    try self.output.append(.{ .token_type = TokenType{ .illegal = &.{current_char} }, .position = cast_index });
                },
            }
        }

        const cast_index: char = @intCast(self.input.len);

        const expr_buff = try self.arena.allocator().dupe(char, try expression_buffer.toOwnedSlice());
        const opr_buff = try self.arena.allocator().dupe(char, try operator_buffer.toOwnedSlice());
        errdefer self.arena.allocator().free(expr_buff);
        errdefer self.arena.allocator().free(opr_buff);

        try self.parse_expr_buffer(expr_buff, cast_index);
        try self.parse_opr_buffer(opr_buff, cast_index);

        try self.output.append(.{
            .token_type = TokenType.eof,
            .position = cast_index,
        });
        return self.output.toOwnedSlice();
    }
};
