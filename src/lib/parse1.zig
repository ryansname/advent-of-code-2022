const std = @import("std");

const assert = std.debug.assert;
const mem = std.mem;
const eql = std.mem.eql;

pub const Parser = struct {
    source: []const u8,
    index: usize = 0,

    pub fn hasMore(self: Parser) bool {
        return self.index < self.source.len;
    }

    pub fn subparse(self: *Parser, needles: []const u8) ?Parser {
        if (!self.hasMore()) return null;

        const start = self.index;
        self.index = mem.indexOfAnyPos(u8, self.source, self.index, needles) orelse self.source.len;
        const substring = self.source[start..self.index];
        self.index += 1; // consume delimiter

        return Parser{ .source = substring };
    }

    pub fn takeDelimiter(self: *Parser, needles: []const u8) ?u8 {
        if (!self.hasMore()) return null;

        const delimiter = self.source[self.index];
        if (mem.indexOfScalar(u8, needles, delimiter) == null) return null;
        self.index += 1;
        return delimiter;
    }

    pub fn skipSequence(self: *Parser, sequence: []const u8) !void {
        for (sequence) |_, i| _ = try self.takeDelimiter(sequence[i .. i + 1]);
    }

    pub fn takeType(self: *Parser, comptime T: type, needles: []const u8) !?T {
        if (!self.hasMore()) return null;

        const start = self.index;
        self.index = mem.indexOfAnyPos(u8, self.source, self.index, needles) orelse self.source.len;
        const result_string = self.source[start..self.index];
        self.index += 1; // Consume delimiter

        switch (@typeInfo(T)) {
            .Int => return try std.fmt.parseInt(T, result_string, 10),
            .Float => return try std.fmt.parseFloat(T, result_string),
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

    pub fn takeTypeByCount(self: *Parser, comptime T: type, count: usize) !?T {
        if (!self.hasMore()) return null;

        const start = self.index;
        self.index += count;

        if (self.index > self.source.len) return error.CouldNotTakeEntireCount;

        const result_string = self.source[start..self.index];

        switch (@typeInfo(T)) {
            .Int => return try std.fmt.parseInt(T, result_string, 10),
            .Float => return try std.fmt.parseFloat(T, result_string),
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
    var parser = Parser.init(
        \\123,123,123,123,123,123,123,123
    );

    var sum: u64 = 0;
    while (try parser.takeType(u64, ",")) |v| {
        sum += v;
    }
    try expectEqual(@as(u64, 984), sum);
}

test "parser take strings" {
    var parser = Parser.init(
        \\hi,hi,hi,hi
    );

    var count: u64 = 0;
    while (try parser.takeType([]const u8, ",")) |string| {
        count += 1;
        try expectEqualStrings("hi", string);
    }
    try expectEqual(@as(u64, 4), count);
}

test "parser multiline types" {
    var parser = Parser.init(
        \\123,123,123,123,123,123,123,123
        \\
        \\hi,hi,hi,hi
    );

    var numbers = parser.subparse("\n").?;
    var sum: u64 = 0;
    while (try numbers.takeType(u64, ",")) |v| {
        sum += v;
    }
    try expectEqual(@as(u64, 984), sum);

    _ = try parser.takeDelimiter("\n");

    var words = parser.subparse("\n").?;
    var count: u64 = 0;
    while (try words.takeType([]const u8, ",")) |string| {
        count += 1;
        try expectEqualStrings("hi", string);
    }
    try expectEqual(@as(u64, 4), count);
}

