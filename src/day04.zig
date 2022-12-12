const debug = std.debug;
const std = @import("std");
const log = std.log;

const Parser = @import("lib/parse1.zig").Parser;

const input = @embedFile("inputs/day4.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const Range = struct { l: u64, h: u64 };
fn parse(parser: *Parser) !Range {
    var range: Range = undefined;
    range.l = (try parser.takeType(u64, "-")).?;
    range.h = (try parser.takeType(u64, ",\n")).?;
    return range;
}

// 24-92,25-93
fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var result: u64 = 0;
    while (parser.hasMore()) {
        const left = try parse(&parser);
        const right = try parse(&parser);

        if (left.l >= right.l and left.h <= right.h or
            right.l >= left.l and right.h <= left.h) result += 1;
    }
    return result;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var result: u64 = 0;
    while (parser.hasMore()) {
        const left = try parse(&parser);
        const right = try parse(&parser);

        const no_overlap = left.h < right.l or left.l > right.h or right.l > left.h or right.h < left.l;
        if (!no_overlap) result += 1;
    }
    return result;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 2), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 4), try part2(test_input));
}

const test_input =
    \\2-4,6-8
    \\2-3,4-5
    \\5-7,7-9
    \\2-8,3-7
    \\6-6,4-6
    \\2-6,4-8
;
