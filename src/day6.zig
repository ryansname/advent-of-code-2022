const debug = std.debug;
const std = @import("std");
const log = std.log;

const Parser = @import("lib/parse1.zig").Parser;

const input = @embedFile("inputs/day6.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var last4 = [_]u8{ 0, 0, 0, 0 };
    last4[0] = parser.source[0];
    last4[1] = parser.source[1];
    last4[2] = parser.source[2];
    last4[3] = parser.source[3];

    for (parser.source[4..]) |c, i| {
        last4[i % 4] = c;
        // Written while covered in doggos, look away
        if (last4[0] == last4[1] or last4[1] == last4[2] or last4[2] == last4[3] or last4[0] == last4[2] or last4[1] == last4[3] or last4[0] == last4[3]) {} else return i + 5;
    }

    return 99999;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var seen_index = [_]usize{0} ** 26;

    var highest_index_with_dupe: usize = 0;
    for (parser.source) |c, i| {
        if (c == '\n') continue;
        const last_seen_index = seen_index[c - 'a'];
        seen_index[c - 'a'] = i;
        if (last_seen_index > highest_index_with_dupe) highest_index_with_dupe = last_seen_index;

        if (i < 14) continue;
        if (highest_index_with_dupe <= i - 14) return i + 1;
    }

    return 99999;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 5), try part1("bvwbjplbgvbhsrlpgdmjqwftvncz"));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 29), try part2("nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg"));
    try std.testing.expectEqual(@as(u64, 26), try part2("zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw"));
}

