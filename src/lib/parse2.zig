const std = @import("std");

const assert = std.debug.assert;
const mem = std.mem;
const eql = std.mem.eql;

const log = std.log.scoped(.Parser);

pub const Parser = struct {
    source: []const u8,
    index: usize = 0,

    pub fn hasMore(self: Parser) bool {
        return self.index < self.source.len;
    }

    pub fn ignore(self: *Parser, string: []const u8) void {
        const ignored = self.source[self.index..(self.index + string.len)];
        if (!std.mem.eql(u8, string, ignored)) {
            log.warn("Ignored '{s}' vs '{s}'", .{ ignored, string });
        }
        self.index += string.len;
    }

    pub fn line(self: *Parser) ?[]const u8 {
        if (!self.hasMore()) return null;

        const start = self.index;
        self.index = mem.indexOfScalarPos(u8, self.source, self.index, '\n') orelse self.source.len;
        defer self.index += 1; // Consume the new line

        return self.source[start..self.index];
    }

    pub fn chunk(self: *Parser, comptime T: type) ?T {
        if (!self.hasMore()) return null;
        if (self.source[self.index] == '\n') return null;

        const needles = " ,:\n";

        const start = self.index;
        self.index = mem.indexOfAnyPos(u8, self.source, self.index, needles) orelse self.source.len;
        const result_string = self.source[start..self.index];

        if (self.hasMore() and self.source[self.index] != '\n') {
            while (self.hasMore() and mem.indexOfScalar(u8, needles, self.source[self.index]) != null) {
                self.index += 1; // Consume delimiter
            }
        }

        switch (@typeInfo(T)) {
            .Int => return std.fmt.parseInt(T, result_string, 10) catch |err| std.debug.panic("error parsing '{s}' to int: {}\n", .{ result_string, err }),
            .Float => return std.fmt.parseFloat(T, result_string) catch |err| std.debug.panic("error parsing '{s}' tp float: {}\n", .{ result_string, err }),
            .Pointer => |P| switch (@typeInfo(P.child)) {
                .Int => |C| {
                    assert(C.bits == 8);
                    return result_string;
                },
                else => return error.UnsupportedType,
            },
            else => return error.UnsupportedType,
        }
    }
};

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;
test "parser take numbers" {
    var parser = Parser{ .source = 
    \\123,123,123,123,123,123,123,123
    };

    var sum: u64 = 0;
    while (parser.chunk(u64)) |v| {
        sum += v;
    }
    try expectEqual(@as(u64, 984), sum);
}

test "parser take spaced numbers" {
    var parser = Parser{ .source = 
    \\123, 123,,123 ,123,123,123,123,123
    };

    var sum: u64 = 0;
    while (parser.chunk(u64)) |v| {
        sum += v;
    }
    try expectEqual(@as(u64, 984), sum);
}

test "parser take lines" {
    var parser = Parser{ .source = 
    \\hi
    \\hi
    \\hi
    \\hi
    };

    var count: u64 = 0;
    while (parser.line()) |string| {
        count += 1;
        try expectEqualStrings("hi", string);
    }
    try expectEqual(@as(u64, 4), count);
}

test "parser take lines ignores blank eof" {
    var parser = Parser{ .source = 
    \\hi
    \\hi
    \\hi
    \\hi
    \\
    };

    var count: u64 = 0;
    while (parser.line()) |string| {
        count += 1;
        try expectEqualStrings("hi", string);
    }
    try expectEqual(@as(u64, 4), count);
}
