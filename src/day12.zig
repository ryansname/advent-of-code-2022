const debug = std.debug;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const BoundedArray = std.BoundedArray;

const Parser = @import("lib/parse2.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day12.txt");

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

const World = struct {
    start: usize,
    width: usize,
    height: usize,
    stride: usize,
    len: usize,
    data: []u8,
    entry_idx: usize,
    exit_idx: usize,
};
fn parse(parser: *Parser, unpassable: u8) !World {
    var input_width = mem.indexOfScalar(u8, parser.source, '\n').?;
    var input_height: usize = 0;
    const stride = input_width + 2;

    var data = std.ArrayList(u8).init(alloc);

    try data.appendNTimes(unpassable, stride);
    while (parser.hasMore()) {
        try data.append(unpassable);
        const row = parser.line() orelse unreachable;
        for (row) |h| {
            switch (h) {
                'a'...'z', 'S', 'E' => try data.append(h),
                else => debug.panic("Unknown value: {c}", .{h}),
            }
        }
        try data.append(unpassable);
        input_height += 1;
    }
    try data.appendNTimes(unpassable, stride);

    const entry_idx = mem.indexOfScalar(u8, data.items, 'S') orelse unreachable;
    const exit_idx = mem.indexOfScalar(u8, data.items, 'E') orelse unreachable;

    data.items[entry_idx] = 'a';
    data.items[exit_idx] = 'z';

    const start = stride + 1;
    const len = input_width * input_height;
    return World{
        .start = start,
        .width = input_width,
        .height = input_height,
        .stride = stride,
        .len = len,
        .data = data.toOwnedSlice(),
        .entry_idx = entry_idx,
        .exit_idx = exit_idx,
    };
}

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };
    const world = try parse(&parser, math.maxInt(u8));
    defer alloc.free(world.data);

    var steps: u64 = 1;
    var seen = try alloc.alloc(bool, world.data.len);
    defer alloc.free(seen);

    var dataA = std.ArrayListUnmanaged(usize){};
    var dataB = std.ArrayListUnmanaged(usize){};
    defer dataA.deinit(alloc);
    defer dataB.deinit(alloc);

    var fringe = &dataA;
    var nextFringe = &dataB;

    try fringe.append(alloc, world.entry_idx);
    seen[world.entry_idx] = true;

    const dirs = .{ 1, world.stride };
    const ops = .{ math.add, math.sub };
    step_loop: while (true) : (steps += 1) {
        debug.assert(fringe != nextFringe);
        debug.assert(nextFringe.items.len == 0);
        debug.assert(fringe.items.len != 0);
        defer {
            const temp = fringe;
            fringe = nextFringe;
            nextFringe = temp;
        }

        while (fringe.popOrNull()) |here_idx| {
            inline for (dirs) |dir| {
                inline for (ops) |op| {
                    const test_idx = try op(usize, here_idx, dir);
                    if (seen[test_idx]) {} else {
                        if (world.data[here_idx] + 1 >= world.data[test_idx]) {
                            if (world.exit_idx == test_idx) break :step_loop;
                            try nextFringe.append(alloc, test_idx);
                            seen[test_idx] = true;
                        }
                    }
                }
            }
        }
    }

    return steps;
}

/// Part 2 is essentially asking for the path from the top to any 'a', with a different filter
fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };
    const world = try parse(&parser, 0);
    defer alloc.free(world.data);

    var steps: u64 = 1;
    var seen = try alloc.alloc(bool, world.data.len);
    defer alloc.free(seen);

    var dataA = std.ArrayListUnmanaged(usize){};
    var dataB = std.ArrayListUnmanaged(usize){};
    defer dataA.deinit(alloc);
    defer dataB.deinit(alloc);

    var fringe = &dataA;
    var nextFringe = &dataB;

    try fringe.append(alloc, world.exit_idx);
    seen[world.exit_idx] = true;

    const dirs = .{ 1, world.stride };
    const ops = .{ math.add, math.sub };
    step_loop: while (true) : (steps += 1) {
        debug.assert(fringe != nextFringe);
        debug.assert(nextFringe.items.len == 0);
        debug.assert(fringe.items.len != 0);
        defer {
            const temp = fringe;
            fringe = nextFringe;
            nextFringe = temp;
        }

        while (fringe.popOrNull()) |here_idx| {
            inline for (dirs) |dir| {
                inline for (ops) |op| {
                    const test_idx = try op(usize, here_idx, dir);
                    if (seen[test_idx]) {} else {
                        if (world.data[here_idx] - 1 <= world.data[test_idx]) {
                            if (world.data[test_idx] == 'a') break :step_loop;
                            try nextFringe.append(alloc, test_idx);
                            seen[test_idx] = true;
                        }
                    }
                }
            }
        }
    }

    return steps;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 31), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 29), try part2(test_input));
}

const test_input =
    \\Sabqponm
    \\abcryxxl
    \\accszExk
    \\acctuvwj
    \\abdefghi
;
