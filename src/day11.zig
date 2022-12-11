const debug = std.debug;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const BoundedArray = std.BoundedArray;

const Parser = @import("lib/parse2.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day11.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const Op = enum { Add, Sub, Mul, Div };
fn charToOp(char: u8) ?Op {
    return switch (char) {
        '+' => .Add,
        '-' => .Sub,
        '*' => .Mul,
        '/' => .Div,
        else => null,
    };
}

const Monkey = struct {
    items: BoundedArray(u64, 128),
    inspections: u64,
    operation_op: Op,
    operation_arg: ?u64,
    test_value: u64,
    true_dest: u64,
    false_dest: u64,
};
//Monkey 0:
//  Starting items: 79, 98
//  Operation: new = old * 19
//  Test: divisible by 23
//    If true: throw to monkey 2
//    If false: throw to monkey 3
//
fn parse(parser: *Parser) !BoundedArray(Monkey, 10) {
    var monkeys = try BoundedArray(Monkey, 10).init(0);

    while (parser.hasMore()) {
        _ = parser.line();

        var monkey = try monkeys.addOne();
        monkey.inspections = 0;

        parser.ignore("  Starting items: ");
        monkey.items = try BoundedArray(u64, 128).init(0);
        while (parser.chunk(u64)) |worry| {
            try monkey.items.append(worry);
        }
        _ = parser.line();

        parser.ignore("  Operation: new = old ");
        monkey.operation_op = charToOp(parser.chunk([]const u8).?[0]).?;
        monkey.operation_arg = if (parser.source[parser.index] != 'o') parser.chunk(u64).? else null;
        _ = parser.line();

        parser.ignore("  Test: divisible by ");
        monkey.test_value = parser.chunk(u64).?;
        _ = parser.line();

        parser.ignore("    If true: throw to monkey ");
        monkey.true_dest = parser.chunk(u64).?;
        _ = parser.line();

        parser.ignore("    If false: throw to monkey ");
        monkey.false_dest = parser.chunk(u64).?;
        _ = parser.line();

        // blank linke between monkeys
        _ = parser.line();
    }

    return monkeys;
}

fn step(monkeys: []Monkey, comptime part: comptime_int, mod: u64) !void {
    for (monkeys) |*m| {
        while (m.items.popOrNull()) |item_worry| {
            const operation_value = m.operation_arg orelse item_worry;
            var new_item_worry = switch (m.operation_op) {
                .Add => item_worry + operation_value,
                .Sub => item_worry - operation_value,
                .Mul => item_worry * operation_value,
                .Div => item_worry / operation_value,
            };
            switch (part) {
                1 => new_item_worry /= mod,
                2 => new_item_worry %= mod,
                else => unreachable,
            }
            m.inspections += 1;

            const next_index = if (new_item_worry % m.test_value == 0) m.true_dest else m.false_dest;
            try monkeys[next_index].items.append(new_item_worry);
        }
    }
}

fn part1(source: []const u8) !u64 {
    return solve(source, 1);
}

fn part2(source: []const u8) !u64 {
    return solve(source, 2);
}

fn solve(source: []const u8, comptime part: comptime_int) !u64 {
    var parser = Parser{ .source = source };
    var monkeys_bounded = try parse(&parser);
    var monkeys = monkeys_bounded.slice();

    const mod = switch (part) {
        1 => 3,
        2 => blk: {
            var result: u64 = 1;
            for (monkeys) |m| result *= m.test_value;
            break :blk result;
        },
        else => unreachable,
    };

    const target_rounds = switch (part) {
        1 => 20,
        2 => 10_000,
        else => unreachable,
    };
    var rounds: usize = 0;
    while (rounds < target_rounds) : (rounds += 1) {
        try step(monkeys, part, mod);
    }

    var max_1 = @max(monkeys[0].inspections, monkeys[1].inspections);
    var max_2 = @min(monkeys[0].inspections, monkeys[1].inspections);
    for (monkeys[2..]) |m| {
        if (m.inspections > max_1) {
            max_2 = max_1;
            max_1 = m.inspections;
        } else if (m.inspections > max_2) {
            max_2 = m.inspections;
        }
    }

    return max_1 * max_2;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 10605), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 2713310158), try part2(test_input));
}

const test_input =
    \\Monkey 0:
    \\  Starting items: 79, 98
    \\  Operation: new = old * 19
    \\  Test: divisible by 23
    \\    If true: throw to monkey 2
    \\    If false: throw to monkey 3
    \\
    \\Monkey 1:
    \\  Starting items: 54, 65, 75, 74
    \\  Operation: new = old + 6
    \\  Test: divisible by 19
    \\    If true: throw to monkey 2
    \\    If false: throw to monkey 0
    \\
    \\Monkey 2:
    \\  Starting items: 79, 60, 97
    \\  Operation: new = old * old
    \\  Test: divisible by 13
    \\    If true: throw to monkey 1
    \\    If false: throw to monkey 3
    \\
    \\Monkey 3:
    \\  Starting items: 74
    \\  Operation: new = old + 3
    \\  Test: divisible by 17
    \\    If true: throw to monkey 0
    \\    If false: throw to monkey 1
;
