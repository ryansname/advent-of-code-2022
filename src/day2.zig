const std = @import("std");
const log = std.log;
const Parser = @import("lib/parse1.zig").Parser;

const input = @embedFile("inputs/day2.txt");

pub fn main() !void {
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var index: u64 = 0;
    var score: u64 = 0;
    while (index < parser.source.len) {
        var lhs = parser.source[index];
        index += 2;
        var rhs = parser.source[index];
        index += 2;

        score += switch (rhs) {
            'X' => 1,
            'Y' => 2,
            'Z' => 3,
            else => 0,
        };

        if (lhs - 'A' == rhs - 'X') score += 3;

        if (lhs == 'A' and rhs == 'Y') score += 6;
        if (lhs == 'B' and rhs == 'Z') score += 6;
        if (lhs == 'C' and rhs == 'X') score += 6;
    }
    return score;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var index: u64 = 0;
    var score: u64 = 0;
    while (index < parser.source.len) {
        var lhs = parser.source[index];
        index += 2;
        var outcome = parser.source[index];
        index += 2;

        // Rock = 1
        // Paper = 2
        // Scissors = 3

        score += switch (lhs) {
            'A' => switch (outcome) { // rock
                'X' => 0 + 3, // lose
                'Y' => 3 + 1, // draw,
                'Z' => 6 + 2, // win,
                else => 0,
            },
            'B' => switch (outcome) { // paper
                'X' => 0 + 1,
                'Y' => 3 + 2,
                'Z' => 6 + 3,
                else => 0,
            },
            'C' => switch (outcome) { // scissors
                'X' => 0 + 2,
                'Y' => 3 + 3,
                'Z' => 6 + 1,
                else => 0,
            },
            else => std.debug.panic("", .{}),
        };
    }
    return score;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 15), try part1(
        \\A Y
        \\B X
        \\C Z
    ));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 12), try part2(
        \\A Y
        \\B X
        \\C Z
    ));
}
