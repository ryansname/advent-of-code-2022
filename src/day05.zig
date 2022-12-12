const debug = std.debug;
const std = @import("std");
const log = std.log;
const mem = std.mem;

const BoundedArray = std.BoundedArray;

const Parser = @import("lib/parse1.zig").Parser;

const input = @embedFile("inputs/day5.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {s}", .{(try part1(input)).slice()});
    log.info("Part 2: {s}", .{(try part2(input)).slice()});
}

const Move = struct {
    count: u64,
    from: usize,
    to: usize,
};
const Puzzle = struct {
    columns: [10]BoundedArray(u8, 100),
    moves: BoundedArray(Move, 1024),
};
fn parse(parser: *Parser) !Puzzle {
    var puzzle: Puzzle = undefined;
    puzzle.columns = .{try BoundedArray(u8, 100).init(0)} ** 10;
    puzzle.moves = try BoundedArray(Move, 1024).init(0);

    var moves: []const u8 = &[0]u8{};
    var col_start: usize = 1;
    for (parser.source) |char, i| switch (char) {
        '1'...'9' => moves = parser.source[(i + 4)..],
        '\n' => if (moves.len > 0) {
            break;
        } else {
            col_start = i + 2;
        },
        '[', ']', ' ' => {},
        else => {
            // log.warn("{c}, {} {}", .{ char, i, col_start });
            try puzzle.columns[@divExact(i - col_start, 4)].append(char);
        },
    };
    for (puzzle.columns) |*col| {
        mem.reverse(u8, col.slice());
    }

    // log.warn("Moves: {s}", .{moves});
    var move_parser = Parser{ .source = moves };
    while (move_parser.hasMore()) {
        var move = try puzzle.moves.addOne();

        move_parser.skipSequence("move ");
        move.count = try move_parser.takeType(u64, " ") orelse unreachable;
        move_parser.skipSequence("from ");
        move.from = try move_parser.takeType(usize, " ") orelse unreachable;
        move_parser.skipSequence("to ");
        move.to = try move_parser.takeType(usize, " \n") orelse unreachable;

        // Change from 1 indexed to 0 indexed
        move.from -= 1;
        move.to -= 1;
    }

    return puzzle;
}

fn part1(source: []const u8) !BoundedArray(u8, 10) {
    var parser = Parser{ .source = source };

    var puzzle = try parse(&parser);

    for (puzzle.moves.slice()) |move| {
        var move_i: usize = 0;
        while (move_i < move.count) : (move_i += 1) {
            // log.warn("{any}", .{move});
            try puzzle.columns[move.to].append(puzzle.columns[move.from].pop());
        }
    }

    var result = try BoundedArray(u8, 10).init(0);
    for (puzzle.columns) |col| {
        if (col.len == 0) break;
        try result.append(col.get(col.len - 1));
    }
    return result;
}

fn part2(source: []const u8) !BoundedArray(u8, 10) {
    var parser = Parser{ .source = source };

    var puzzle = try parse(&parser);

    for (puzzle.moves.slice()) |move| {
        // log.warn("{any}", .{move});
        const remove_i = puzzle.columns[move.from].len - move.count;
        const removed_slice = puzzle.columns[move.from].slice()[remove_i..];
        debug.assert(removed_slice.len == move.count);

        try puzzle.columns[move.to].appendSlice(removed_slice);
        try puzzle.columns[move.from].resize(remove_i);
    }

    var result = try BoundedArray(u8, 10).init(0);
    for (puzzle.columns) |col| {
        if (col.len == 0) break;
        try result.append(col.get(col.len - 1));
    }
    return result;
}

test "part1" {
    try std.testing.expectEqualStrings("CMZ", (try part1(test_input)).slice());
}
test "part2" {
    try std.testing.expectEqualStrings("MCD", (try part2(test_input)).slice());
}

const test_input =
    \\    [D]
    \\[N] [C]
    \\[Z] [M] [P]
    \\ 1   2   3 
    \\
    \\move 1 from 2 to 1
    \\move 3 from 1 to 3
    \\move 2 from 2 to 1
    \\move 1 from 1 to 2
;
