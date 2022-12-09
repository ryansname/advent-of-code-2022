const debug = std.debug;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const Parser = @import("lib/parse1.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day9.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const Puzzle = struct {};
fn parse(parser: *Parser) !Puzzle {
    _ = parser;
    return Puzzle{};
}

fn addHit(hits: *std.AutoHashMap(V2, void), loc: V2) !void {
    try hits.put(loc, {});
}

const V2 = struct { x: i32, y: i32 };
fn part1(source: []const u8) !u64 {
    return solve(source, 2);
}

fn part2(source: []const u8) !u64 {
    return solve(source, 10);
}

fn solve(source: []const u8, comptime knots: usize) !u64 {
    var parser = Parser{ .source = source };

    var hits = std.AutoHashMap(V2, void).init(alloc);
    defer hits.deinit();

    var snake = [_]V2{.{ .x = 0, .y = 0 }} ** knots;
    var head = &snake[0];
    var tail = &snake[knots - 1];
    try addHit(&hits, tail.*);

    while (parser.hasMore()) {
        var line = parser.subparse("\n") orelse unreachable;

        const dir = try line.takeType([]const u8, " ") orelse unreachable;
        var amount = try line.takeType(u32, "\n") orelse unreachable;

        while (amount > 0) : (amount -= 1) {
            switch (dir[0]) {
                'U' => head.y -= 1,
                'D' => head.y += 1,
                'L' => head.x -= 1,
                'R' => head.x += 1,
                else => unreachable,
            }

            for (snake[1..]) |*b, i| {
                const a = snake[i]; // i is already one less because of the slice

                // If touching, do nothing
                if (try math.absInt(a.x - b.x) <= 1 and try math.absInt(a.y - b.y) <= 1) continue;
                const x_dir = math.sign(a.x - b.x);
                const y_dir = math.sign(a.y - b.y);

                b.x += x_dir;
                b.y += y_dir;
                // If the head is ever two steps directly up, down, left, or right from the tail, the tail must also move one step in that direction so it remains close enough:
                // Otherwise, if the head and tail aren't touching and aren't in the same row or column, the tail always moves one step diagonally to keep up:
            }
            // log.warn("Head {} {}, tail {} {}", .{ head.x, head.y, tail.x, tail.y });
            try addHit(&hits, tail.*);
        }
    }

    return hits.count();
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 13), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 36), try part2(test_input_2));
}

const test_input =
    \\R 4
    \\U 4
    \\L 3
    \\D 1
    \\R 4
    \\D 1
    \\L 5
    \\R 2
;

const test_input_2 =
    \\R 5
    \\U 8
    \\L 8
    \\D 3
    \\R 17
    \\D 10
    \\L 25
    \\U 20
;
