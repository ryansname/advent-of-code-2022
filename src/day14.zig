const debug = std.debug;
const fmt = std.fmt;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const BoundedArray = std.BoundedArray;

const Parser = @import("lib/parse2.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day14.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const V2 = struct { x: u64, y: u64 };
const State = enum { Air, Sand, Wall, Void };
const World = struct {
    start: usize,
    width: usize,
    height: usize,
    stride: usize,
    x_offset: usize,
    data: []State,

    pub fn pointToIndex(world: World, point: V2) usize {
        return world.start + point.x - world.x_offset + (point.y * world.stride);
    }
};

const START_POINT = V2{ .x = 500, .y = 0 };

fn buildWorld(source: []const u8, comptime part: usize) !World {
    var wall_pairs = std.ArrayListUnmanaged([2]V2){};

    var line_iter = mem.split(u8, source, "\n");
    var line_num: usize = 1;
    while (line_iter.next()) |line| : (line_num += 1) {
        if (line.len == 0) continue;

        var start_point: ?V2 = null;
        var pair_iter = mem.split(u8, line, " -> ");

        while (pair_iter.next()) |pair| {
            const comma_idx = mem.indexOfScalar(u8, pair, ',') orelse debug.panic("Invalid pair on line {}: {s}", .{ line_num, pair });
            const point = V2{
                .x = try fmt.parseInt(u64, pair[0..comma_idx], 10),
                .y = try fmt.parseInt(u64, pair[(1 + comma_idx)..], 10),
            };

            if (start_point) |start| {
                try wall_pairs.append(alloc, .{ start, point });
            }
            start_point = point;
        }
    }

    // for (wall_pairs.items) |wp| log.warn("x: {: >3}, y: {: >3}", wp);

    const bounds = blk: {
        var min_x: usize = math.maxInt(usize);
        var max_x: usize = 0;
        var max_y: usize = 0;

        for (wall_pairs.items) |pair| {
            min_x = math.min3(min_x, pair[0].x, pair[1].x);
            max_x = math.max3(max_x, pair[0].x, pair[1].x);
            max_y = math.max3(max_y, pair[0].y, pair[1].y);
        }
        break :blk .{
            .min_x = min_x,
            .max_x = max_x,
            .max_y = max_y,
        };
    };

    const height = bounds.max_y + 3;
    const width = @max(bounds.max_x - bounds.min_x, 2 * height);

    var data = try alloc.alloc(State, width * height);
    mem.set(State, data, .Air);

    const fill = if (part == 1) .Void else .Wall;
    mem.set(State, data[width * (height - 1) ..], fill);

    var world = World{
        .start = 0,
        .width = width,
        .height = height,
        .stride = width,
        .x_offset = (START_POINT.x - width / 2),
        .data = data,
    };

    for (wall_pairs.items) |pair| {
        const start_pair_idx: usize = if (pair[0].x < pair[1].x or pair[0].y < pair[1].y) 0 else 1;
        const end_pair_idx = 1 - start_pair_idx;

        const start = pair[start_pair_idx];
        const end = pair[end_pair_idx];

        const delta = if (start.x == end.x) width else 1;
        const end_idx = world.pointToIndex(end);
        var idx = world.pointToIndex(start);
        while (idx <= end_idx) : (idx += delta) {
            // log.warn("Wall at {}", .{idx});
            world.data[idx] = .Wall;
        }
    }

    return world;
}

fn step(world: *World) State {
    var here = world.pointToIndex(START_POINT);

    next_step: while (true) {
        // First try moving down
        // Then down + left
        // Then down + right
        const test_points = .{ here + world.stride, here + world.stride - 1, here + world.stride + 1 };
        inline for (test_points) |test_idx| {
            const test_state = world.data[test_idx];
            // log.warn("Testing idx {}, got: {}", .{ test_idx, test_state });
            switch (test_state) {
                .Void => return .Void,
                .Sand, .Wall => {},
                .Air => {
                    here = test_idx;
                    continue :next_step;
                },
            }
        }

        debug.assert(world.data[here] == .Air);
        world.data[here] = .Sand;
        // log.warn("Placed sand at {}", .{here});
        return .Air;
    }
}

fn print(world: World) void {
    const start = world.pointToIndex(START_POINT);
    for (world.data) |state, i| {
        if (i % world.width == 0) debug.print("\n", .{});
        const char: u8 = switch (state) {
            .Wall => '#',
            .Air => ' ',
            .Sand => 'o',
            .Void => 'X',
        };

        if (i == start) {
            debug.print("v", .{});
        } else {
            debug.print("{c}", .{char});
        }
    }
    debug.print("\n", .{});
}

fn part1(source: []const u8) !u64 {
    var world = try buildWorld(source, 1);

    var sands: u64 = 0;
    while (true) : (sands += 1) {
        const result = step(&world);
        if (result == .Void) break;
    }

    return sands;
}

fn part2(source: []const u8) !u64 {
    var world = try buildWorld(source, 2);

    const test_idx = world.pointToIndex(START_POINT);

    var sands: u64 = 0;
    while (world.data[test_idx] == .Air) : (sands += 1) {
        _ = step(&world);
    }

    // print(world);
    return sands;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 24), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 93), try part2(test_input));
}

const test_input =
    \\498,4 -> 498,6 -> 496,6
    \\503,4 -> 502,4 -> 502,9 -> 494,9
;
