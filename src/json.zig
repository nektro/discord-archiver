const std = @import("std");

pub const Value = union(enum) {
    Object: []Member,
    Array: []Value,
    String: []const u8,
    Number: f64,
    Bool: bool,
    Null: void,

    pub fn get(self: Value, key: []const u8) ?Value {
        if (self == .Object) {
            for (self.Object) |member| {
                if (std.mem.eql(u8, member.key, key)) {
                    return member.value;
                }
            }
        }
        return null;
    }

    pub fn fetch(self: Value, query: anytype) ?Value {
        if (query.len == 0) {
            return self;
        }
        const i = query[0];
        const t = @TypeOf(i);
        if (t == []const u8) {
            if (self.get(i)) |v| {
                return v.fetch(query[1..]);
            }
        }
        if (@typeInfo(t) == .Int) {
            if (self == .Array) {
                return self.Array[i].fetch(query[1..]);
            }
        }
        return null;
    }

    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        switch (self) {
            .Object => {
                try writer.writeAll("{");
                for (self.Object) |member, i| {
                    if (i > 0) {
                        try writer.writeAll(", ");
                    }
                    try writer.print("{}", .{member});
                }
                try writer.writeAll("}");
            },
            .Array => {
                try writer.writeAll("[");
                for (self.Array) |val, i| {
                    if (i > 0) {
                        try writer.writeAll(", ");
                    }
                    try writer.print("{}", .{val});
                }
                try writer.writeAll("]");
            },
            .String => {
                try writer.print("\"{s}\"", .{self.String});
            },
            .Number => {
                try writer.print("{}", .{self.Number});
            },
            .Bool => {
                try writer.print("{}", .{self.Bool});
            },
            .Null => {
                try writer.writeAll("null");
            },
        }
    }
};

pub const Member = struct {
    key: []const u8,
    value: Value,

    pub fn format(self: Member, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        try writer.print("\"{s}\": {}", .{ self.key, self.value });
    }
};

const Parser = struct {
    alloc: *std.mem.Allocator,
    p: std.json.StreamingParser,
    input: []const u8,
    index: usize,
    tok2: ?std.json.Token,

    pub fn next(self: *Parser) !?std.json.Token {
        if (self.tok2) |t2| {
            defer self.tok2 = null;
            return t2;
        }
        while (self.index < self.input.len) {
            var tok: ?std.json.Token = null;
            var tok2: ?std.json.Token = null;
            const b = self.input[self.index];
            try self.p.feed(b, &tok, &tok2);
            self.index += 1;
            if (tok) |_| {} else {
                continue;
            }
            if (tok2) |t2| {
                self.tok2 = t2;
            }
            return tok;
        }
        return null;
    }

    pub const Error =
        std.fs.File.OpenError ||
        std.json.StreamingParser.Error ||
        std.mem.Allocator.Error ||
        error{InvalidCharacter} ||
        error{ JsonExpectedObjKey, JsonExpectedValueStartGotEnd };
};

pub fn parse(alloc: *std.mem.Allocator, input: []const u8) Parser.Error!Value {
    const p = &Parser{
        .alloc = alloc,
        .p = std.json.StreamingParser.init(),
        .input = input,
        .index = 0,
        .tok2 = null,
    };
    return try parse_value(p, null);
}

fn parse_value(p: *Parser, start: ?std.json.Token) Parser.Error!Value {
    const tok = start orelse try p.next();
    return switch (tok.?) {
        .ObjectBegin => |t| Value{ .Object = try parse_object(p) },
        .ObjectEnd => |t| error.JsonExpectedValueStartGotEnd,
        .ArrayBegin => |t| Value{ .Array = try parse_array(p) },
        .ArrayEnd => |t| error.JsonExpectedValueStartGotEnd,
        .String => |t| Value{ .String = t.slice(p.input, p.index - 1) },
        .Number => |t| Value{ .Number = try std.fmt.parseFloat(f64, t.slice(p.input, p.index - 1)) },
        .True => Value{ .Bool = true },
        .False => Value{ .Bool = false },
        .Null => Value{ .Null = {} },
    };
}

fn parse_object(p: *Parser) Parser.Error![]Member {
    const array = &std.ArrayList(Member).init(p.alloc);
    defer array.deinit();
    while (true) {
        const tok = try p.next();
        if (tok.? == .ObjectEnd) {
            return array.toOwnedSlice();
        }
        if (tok.? != .String) {
            return error.JsonExpectedObjKey;
        }
        try array.append(Member{
            .key = tok.?.String.slice(p.input, p.index - 1),
            .value = try parse_value(p, null),
        });
    }
}

fn parse_array(p: *Parser) Parser.Error![]Value {
    const array = &std.ArrayList(Value).init(p.alloc);
    defer array.deinit();
    while (true) {
        const tok = try p.next();
        if (tok.? == .ArrayEnd) {
            return array.toOwnedSlice();
        }
        try array.append(try parse_value(p, tok.?));
    }
}
