const debug = std.debug;
const fmt = std.fmt;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const ArrayListUnmanaged = std.ArrayListUnmanaged;
const BoundedArray = std.BoundedArray;

const Parser = @import("lib/parse2.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day21.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const Monkey = union(enum) {
    yell: i64,
    math: struct {
        lhs: []const u8,
        rhs: []const u8,
        op: u8,
    },
};

const State = struct {
    monkeys: std.StringHashMapUnmanaged(Monkey),
};

fn parse(source: []const u8) !State {
    var result = State{
        .monkeys = std.StringHashMapUnmanaged(Monkey){},
    };

    var parser = Parser{ .source = source };
    while (parser.hasMore()) : (_ = parser.line()) {
        const name = parser.chunk([]const u8).?;
        const num_or_lhs = parser.chunk([]const u8).?;

        const monkey: Monkey = if (std.ascii.isDigit(num_or_lhs[0])) .{
            .yell = try fmt.parseInt(i64, num_or_lhs, 10),
        } else blk: {
            const op_char = parser.chunk([]const u8).?;
            const rhs = parser.chunk([]const u8).?;
            break :blk .{
                .math = .{
                    .lhs = num_or_lhs,
                    .rhs = rhs,
                    .op = op_char[0],
                },
            };
        };

        try result.monkeys.put(alloc, name, monkey);
    }
    return result;
}

fn startYellin1(state: *State) void {
    // This is the funnier way to implement it
    var made_change = true;
    const monkeys = state.monkeys;
    while (made_change) {
        made_change = false;

        var iter = monkeys.iterator();
        while (iter.next()) |entry| {
            const monkey = entry.value_ptr.*;
            switch (monkey) {
                .yell => continue,
                .math => |math_monkey| {
                    const lhs = monkeys.get(math_monkey.lhs).?;
                    const rhs = monkeys.get(math_monkey.rhs).?;
                    const op = math_monkey.op;
                    const result = if (lhs == .yell and rhs == .yell) switch (op) {
                        '+' => lhs.yell + rhs.yell,
                        '-' => lhs.yell - rhs.yell,
                        '*' => lhs.yell * rhs.yell,
                        '/' => @divExact(lhs.yell, rhs.yell),
                        else => unreachable,
                    } else continue;
                    made_change = true;
                    entry.value_ptr.* = .{ .yell = result };
                },
            }
        }
    }
}

fn part1(source: []const u8) !i64 {
    var state = try parse(source);

    startYellin1(&state);

    return state.monkeys.get("root").?.yell;
}

fn startYellin2(state: *State) !void {
    // This is the funnier way to implement it
    var made_change = true;
    const monkeys = state.monkeys;
    while (made_change) {
        made_change = false;

        var iter = monkeys.iterator();
        while (iter.next()) |entry| {
            const monkey = entry.value_ptr.*;
            switch (monkey) {
                .yell => continue,
                .math => |math_monkey| {
                    const lhs = monkeys.get(math_monkey.lhs).?;
                    const rhs = monkeys.get(math_monkey.rhs).?;
                    const op = math_monkey.op;
                    const result = if (lhs == .yell and rhs == .yell) switch (op) {
                        '+' => try math.add(i64, lhs.yell, rhs.yell),
                        '-' => try math.sub(i64, lhs.yell, rhs.yell),
                        '*' => try math.mul(i64, lhs.yell, rhs.yell),
                        '/' => try math.divExact(i64, lhs.yell, rhs.yell),
                        else => unreachable,
                    } else continue;
                    made_change = true;
                    entry.value_ptr.* = .{ .yell = result };
                },
            }
        }
    }
}
fn part2(source: []const u8) !i64 {
    var progress = std.Progress{
        .dont_print_on_dumb = true,
    };
    var node = progress.start("Guessing", math.maxInt(i64));

    var is_greater: ?bool = null;

    var offset: i64 = 0;
    var delta: i64 = 1000000000;
    var attempts: i64 = 1;
    while (true) : (attempts += delta) {
        defer node.completeOne();
        var state = try parse(source);
        const root = state.monkeys.get("root").?.math;
        const human = state.monkeys.getPtr("humn").?;

        // By inspection with delta = 1
        const guess = (attempts + offset) * 810 + 52;
        human.* = .{ .yell = guess };

        startYellin2(&state) catch continue;

        const eql1 = state.monkeys.get(root.lhs).?;
        const eql2 = state.monkeys.get(root.rhs).?;

        progress.log("Guessed {}, got {} {}\n", .{ guess, eql1, eql2 });
        if (eql1.yell == eql2.yell) return state.monkeys.get("humn").?.yell;

        if (is_greater) |is_gt| {
            if (is_gt and eql1.yell < eql2.yell or !is_gt and eql1.yell > eql2.yell) {
                progress.log("Passed answer, reducing delta and retrying\n", .{});
                offset += attempts - delta;
                delta = @divExact(delta, 10);
                attempts = 1;
            }
        } else {
            is_greater = eql1.yell > eql2.yell;
        }
    }

    return error.NotFound;
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 152), try part1(test_input));
}
test "part2" {
    // try std.testing.expectEqual(@as(i64, 301), try part2(test_input));
}

const test_input =
    \\root: pppw + sjmn
    \\dbpl: 5
    \\cczh: sllz + lgvd
    \\zczc: 2
    \\ptdq: humn - dvpt
    \\dvpt: 3
    \\lfqf: 4
    \\humn: 5
    \\ljgn: 2
    \\sjmn: drzm * dbpl
    \\sllz: 4
    \\pppw: cczh / lfqf
    \\lgvd: ljgn * ptdq
    \\drzm: hmdt - zczc
    \\hmdt: 32
;
