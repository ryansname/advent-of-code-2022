const debug = std.debug;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const Parser = @import("lib/parse1.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day10.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    const result = try part2(input);
    var i: usize = 0;
    while (i < result.len) : (i += 40) {
        log.info("Part 2: {s}", .{result[i..(i + 40)]});
    }
}

const Puzzle = struct {};
fn parse(parser: *Parser) !Puzzle {
    _ = parser;
    return Puzzle{};
}

fn part1(source: []const u8) !i64 {
    var parser = Parser{ .source = source };
    var result: i64 = 0;

    var threshold: i64 = 20;

    var cycle: u64 = 0;
    var reg_x: i64 = 1;

    while (try parser.takeType([]const u8, " \n")) |inst| {
        // debug.print("After cycle {}, value = {}\n", .{ cycle, reg_x });

        var cycles_before_operation: u64 = switch (inst[0]) {
            'n' => 1,
            'a' => 2,
            else => unreachable,
        };

        const reg_x_before = reg_x;
        cycle += cycles_before_operation;
        switch (inst[0]) {
            'n' => {},
            'a' => {
                const value = try parser.takeType(i64, "\n") orelse unreachable;
                reg_x += value;
            },
            else => debug.panic("unknown instruction: {s}", .{inst}),
        }

        if (cycle >= threshold) {
            const reg_value = reg_x_before;
            const delta = threshold * reg_value;
            // log.warn("Delta result: t{} x v{} = {}, cycle = {}", .{ threshold, reg_value, delta, cycle });
            result += delta;
            threshold += 40;
        }
    }

    return result;
}

fn part2(source: []const u8) ![240]u8 {
    var parser = Parser{ .source = source };
    var result = try std.BoundedArray(u8, 240).init(0);

    var cycle: u64 = 0;
    var reg_x: i64 = 1;

    while (try parser.takeType([]const u8, " \n")) |inst| {
        // debug.print("After cycle {}, value = {}\n", .{ cycle, reg_x });

        var cycles_before_operation: u64 = switch (inst[0]) {
            'n' => 1,
            'a' => 2,
            else => unreachable,
        };

        while (cycles_before_operation > 0) : (cycles_before_operation -= 1) {
            const is_lit = try math.absInt(@intCast(i64, cycle % 40) - reg_x) < 2;
            try result.append(if (is_lit) '#' else '.');
            cycle += 1;
        }

        switch (inst[0]) {
            'n' => {},
            'a' => {
                const value = try parser.takeType(i64, "\n") orelse unreachable;
                reg_x += value;
            },
            else => debug.panic("unknown instruction: {s}", .{inst}),
        }
    }

    return result.buffer;
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 13140), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqualStrings(part_2_test_output, &try part2(test_input));
}

const test_input =
    \\addx 15
    \\addx -11
    \\addx 6
    \\addx -3
    \\addx 5
    \\addx -1
    \\addx -8
    \\addx 13
    \\addx 4
    \\noop
    \\addx -1
    \\addx 5
    \\addx -1
    \\addx 5
    \\addx -1
    \\addx 5
    \\addx -1
    \\addx 5
    \\addx -1
    \\addx -35
    \\addx 1
    \\addx 24
    \\addx -19
    \\addx 1
    \\addx 16
    \\addx -11
    \\noop
    \\noop
    \\addx 21
    \\addx -15
    \\noop
    \\noop
    \\addx -3
    \\addx 9
    \\addx 1
    \\addx -3
    \\addx 8
    \\addx 1
    \\addx 5
    \\noop
    \\noop
    \\noop
    \\noop
    \\noop
    \\addx -36
    \\noop
    \\addx 1
    \\addx 7
    \\noop
    \\noop
    \\noop
    \\addx 2
    \\addx 6
    \\noop
    \\noop
    \\noop
    \\noop
    \\noop
    \\addx 1
    \\noop
    \\noop
    \\addx 7
    \\addx 1
    \\noop
    \\addx -13
    \\addx 13
    \\addx 7
    \\noop
    \\addx 1
    \\addx -33
    \\noop
    \\noop
    \\noop
    \\addx 2
    \\noop
    \\noop
    \\noop
    \\addx 8
    \\noop
    \\addx -1
    \\addx 2
    \\addx 1
    \\noop
    \\addx 17
    \\addx -9
    \\addx 1
    \\addx 1
    \\addx -3
    \\addx 11
    \\noop
    \\noop
    \\addx 1
    \\noop
    \\addx 1
    \\noop
    \\noop
    \\addx -13
    \\addx -19
    \\addx 1
    \\addx 3
    \\addx 26
    \\addx -30
    \\addx 12
    \\addx -1
    \\addx 3
    \\addx 1
    \\noop
    \\noop
    \\noop
    \\addx -9
    \\addx 18
    \\addx 1
    \\addx 2
    \\noop
    \\noop
    \\addx 9
    \\noop
    \\noop
    \\noop
    \\addx -1
    \\addx 2
    \\addx -37
    \\addx 1
    \\addx 3
    \\noop
    \\addx 15
    \\addx -21
    \\addx 22
    \\addx -6
    \\addx 1
    \\noop
    \\addx 2
    \\addx 1
    \\noop
    \\addx -10
    \\noop
    \\noop
    \\addx 20
    \\addx 1
    \\addx 2
    \\addx 2
    \\addx -6
    \\addx -11
    \\noop
    \\noop
    \\noop
    \\
;

const part_2_test_output =
    \\##..##..##..##..##..##..##..##..##..##..###...###...###...###...###...###...###.####....####....####....####....####....#####.....#####.....#####.....#####.....######......######......######......###########.......#######.......#######.....
;
