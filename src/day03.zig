const debug = std.debug;
const std = @import("std");
const log = std.log;

const Parser = @import("lib/parse1.zig").Parser;

const input = @embedFile("inputs/day3.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

fn parse(source: []const u8) ['z' + 1]u8 {
    var buckets = [_]u8{0} ** ('z' + 1);
    for (source) |item| {
        buckets[item] += 1;
    }
    return buckets;
}

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var result: u64 = 0;
    while (parser.subparse("\n")) |subparser| {
        const line = subparser.source;
        var left = parse(line[0 .. line.len / 2]);
        var right = parse(line[line.len / 2 ..]);

        debug.assert(left.len == right.len);
        var i: usize = 0;
        while (i < left.len) : (i += 1) {
            if (left[i] > 0 and right[i] > 0) {
                result += switch (i) {
                    'a'...'z' => i - 'a' + 1,
                    'A'...'Z' => i - 'A' + 27,
                    else => unreachable,
                };
            }
        }
    }
    return result;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var result: u64 = 0;
    while (parser.subparse("\n")) |subparser| {
        var sacks: [3]['z' + 1]u8 = undefined;
        sacks[0] = parse(subparser.source);
        sacks[1] = parse(parser.subparse("\n").?.source);
        sacks[2] = parse(parser.subparse("\n").?.source);

        var i: usize = 0;
        while (i < sacks[0].len) : (i += 1) {
            if (sacks[0][i] > 0 and sacks[1][i] > 0 and sacks[2][i] > 0) {
                result += switch (i) {
                    'a'...'z' => i - 'a' + 1,
                    'A'...'Z' => i - 'A' + 27,
                    else => unreachable,
                };
            }
        }
    }
    return result;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 157), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 70), try part2(test_input));
}

const test_input =
    \\vJrwpWtwJgWrhcsFMMfFFhFp
    \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
    \\PmmdzqPrVvPwwTWBwg
    \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
    \\ttgJtRGJQctTZtZT
    \\CrZsJsPPZsGzwwsLwLmpwMDw
;
