const debug = std.debug;
const fmt = std.fmt;
const log = std.log;
const math = std.math;
const mem = std.mem;
const std = @import("std");
const sort = std.sort;

const BoundedArray = std.BoundedArray;

const Parser = @import("lib/parse2.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day13.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const State = enum { Good, Bad, Same };

fn isInteger(packet: u8) bool {
    return packet[0] != '[';
}

const ValidityParser = struct {
    parser: Parser,
    override_number: ?u64 = null, // if not null, return this from classify
    overrides: u32 = 0, // if override_number is null, and this is > 0 return .ListEnd

    fn override(self: *ValidityParser, number: u64) void {
        self.override_number = number;
        self.overrides += 1;
    }
};
const Class = union(enum) {
    ListStart: void,
    ListEnd: void,
    Number: u64,
};

fn classify(parser: *ValidityParser) Class {
    if (parser.override_number) |number| {
        parser.override_number = null;
        return .{ .Number = number };
    }

    if (parser.overrides > 0) {
        parser.overrides -= 1;
        return .{ .ListEnd = {} };
    }

    while (parser.parser.source[parser.parser.index] == ',') {
        parser.parser.index += 1;
    }
    switch (parser.parser.source[parser.parser.index]) {
        '[' => {
            parser.parser.index += 1;
            return .{ .ListStart = {} };
        },
        ']' => {
            parser.parser.index += 1;
            return .{ .ListEnd = {} };
        },
        else => {
            const source = parser.parser.source;
            const end_idx = mem.indexOfAnyPos(u8, source, parser.parser.index, ",]") orelse source.len;

            const number = fmt.parseInt(u64, source[parser.parser.index..end_idx], 10) catch unreachable;
            parser.parser.index = end_idx;
            return .{ .Number = number };
        },
    }
}

fn packetsAreValid2(left: []const u8, right: []const u8) bool {
    var left_parser = ValidityParser{ .parser = Parser{ .source = left } };
    var right_parser = ValidityParser{ .parser = Parser{ .source = right } };

    while (true) {
        const left_class = classify(&left_parser);
        const right_class = classify(&right_parser);

        // log.warn("Consider {} vs {}", .{ left_class, right_class });

        switch (left_class) {
            .ListStart => switch (right_class) {
                .ListStart => {}, // Continue
                .ListEnd => return false, // Left is longer than right
                .Number => |right_number| right_parser.override(right_number),
            },
            .ListEnd => switch (right_class) {
                .ListStart => return true, // Right is longer than left
                .ListEnd => {}, // Continue, Lists are the same length
                .Number => return true, // Right is longer than left
            },
            .Number => |left_number| switch (right_class) {
                .ListStart => left_parser.override(left_number),
                .ListEnd => return false, // Left is longer than right
                .Number => |right_number| {
                    if (left_number < right_number) return true;
                    if (left_number > right_number) return false;
                },
            },
        }
    }
}

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var result: u64 = 0;
    var index: u64 = 1;
    while (parser.line()) |left| : (index += 1) {
        const right = parser.line().?;
        // log.warn("Comparing {s} and {s}", .{ left, right });

        if (packetsAreValid2(left, right)) {
            // log.warn("Index {} is valid", .{index});
            result += index;
        }

        _ = parser.line() orelse break;
    }

    return result;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var lines = std.ArrayListUnmanaged([]const u8){};
    try lines.append(alloc, "[[2]]");
    try lines.append(alloc, "[[6]]");

    while (parser.line()) |line| {
        if (line.len == 0) continue;
        try lines.append(alloc, line);
    }

    const sortFn = struct {
        fn sortFn(context: void, left: []const u8, right: []const u8) bool {
            _ = context;
            return packetsAreValid2(left, right);
        }
    }.sortFn;
    sort.sort([]const u8, lines.items, {}, sortFn);

    var result: u64 = 1;
    for (lines.items) |line, i| {
        if (mem.eql(u8, line, "[[2]]") or mem.eql(u8, line, "[[6]]")) {
            result *= i + 1;
        }
    }

    return result;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 13), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 140), try part2(test_input));
}

const test_input =
    \\[1,1,3,1,1]
    \\[1,1,5,1,1]
    \\
    \\[[1],[2,3,4]]
    \\[[1],4]
    \\
    \\[9]
    \\[[8,7,6]]
    \\
    \\[[4,4],4,4]
    \\[[4,4],4,4,4]
    \\
    \\[7,7,7,7]
    \\[7,7,7]
    \\
    \\[]
    \\[3]
    \\
    \\[[[]]]
    \\[[]]
    \\
    \\[1,[2,[3,[4,[5,6,7]]]],8,9]
    \\[1,[2,[3,[4,[5,6,0]]]],8,9]
;
