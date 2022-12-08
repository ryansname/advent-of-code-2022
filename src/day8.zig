const debug = std.debug;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const Parser = @import("lib/parse1.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day8.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const Puzzle = struct {
    start: usize,
    width: usize,
    height: usize,
    stride: usize,
    len: usize,
    data: []u8,
};
fn parse(parser: *Parser) !Puzzle {
    var input_width = mem.indexOfScalar(u8, parser.source, '\n').?;
    var input_height: usize = 0;
    const stride = input_width + 2;

    var data = std.ArrayList(u8).init(alloc);

    try data.appendNTimes(0, stride);
    while (parser.hasMore()) {
        try data.append(0);
        const value = try parser.takeType([]const u8, "\n") orelse unreachable;
        for (value) |v| try data.append(v - '0' + 1); // This makes any 0 height trees around the edge visible
        try data.append(0);
        input_height += 1;
    }
    try data.appendNTimes(0, stride);

    const start = stride + 1;
    const len = input_width * input_height;
    return Puzzle{
        .start = start,
        .width = input_width,
        .height = input_height,
        .stride = stride,
        .len = len,
        .data = data.toOwnedSlice(),
    };
}

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };
    var puzzle = try parse(&parser);
    defer alloc.free(puzzle.data);

    var result: u64 = 0;

    var row: usize = 0;
    while (row < puzzle.height) : (row += 1) {
        var col: usize = 0;
        next_tree: while (col < puzzle.width) : (col += 1) {
            const i = puzzle.start + puzzle.stride * row + col;
            const this_height = puzzle.data[i];

            const deltas = .{ puzzle.stride, 1 };
            const ops = .{ math.sub, math.add };
            inline for (deltas) |delta| {
                inline for (ops) |op| {
                    var test_i = try op(usize, i, delta);
                    while (puzzle.data[test_i] != 0) : (test_i = try op(usize, test_i, delta)) {
                        if (this_height <= puzzle.data[test_i]) break;
                    } else {
                        result += 1;
                        continue :next_tree;
                    }
                }
            }
        }
    }

    return result;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };
    var puzzle = try parse(&parser);
    defer alloc.free(puzzle.data);

    var result: u64 = 0;

    var row: usize = 0;
    while (row < puzzle.height) : (row += 1) {
        var col: usize = 0;
        next_tree: while (col < puzzle.width) : (col += 1) {
            const i = puzzle.start + puzzle.stride * row + col;
            const this_height = puzzle.data[i];
            var this_score: u64 = 1;

            const deltas = .{ puzzle.stride, 1 };
            const ops = .{ math.sub, math.add };
            inline for (deltas) |delta| {
                inline for (ops) |op| {
                    var dir_score: u64 = 0;
                    var test_i = try op(usize, i, delta);
                    while (puzzle.data[test_i] != 0) : (test_i = try op(usize, test_i, delta)) {
                        dir_score += 1;
                        if (this_height <= puzzle.data[test_i]) break;
                    }
                    if (dir_score == 0) continue :next_tree;
                    this_score *= dir_score;
                }
            }

            // log.warn("Testing vs {} = {}", .{ this_height, visible });
            if (this_score > result) result = this_score;
        }
    }

    return result;
}

test "part1 real" {
    try std.testing.expectEqual(@as(u64, 1763), try part1(input));
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 21), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 8), try part2(test_input));
}

const test_input =
    \\30373
    \\25512
    \\65332
    \\33549
    \\35390
;
