const std = @import("std");
const log = std.log;
const Parser = @import("lib/parse1.zig").Parser;

const input = @embedFile("inputs/day1.txt");

pub fn main() !void {
    var parser = Parser{ .source = input };

    var max1: u64 = 0;
    var max2: u64 = 0;
    var max3: u64 = 0;
    var total: u64 = 0;
    while (try parser.takeType(u64, "\n")) |calories| {
        total += calories;

        if (parser.takeDelimiter("\n")) |_| {
            if (total > max1) {
                max3 = max2;
                max2 = max1;
                max1 = total;
            } else if (total > max2) {
                max3 = max2;
                max2 = total;
            } else if (total > max3) {
                max3 = total;
            }

            total = 0;
        }
    }
    log.info("Part 1: {}", .{max1});
    log.info("Part 2: {}", .{max1 + max2 + max3});
}
