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

const input = @embedFile("inputs/day17.txt");

const PRINT_WORLD = false;

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input[0 .. input.len - 1], 2022)});
    log.info("Part 2: {}", .{try part2(input[0 .. input.len - 1], 1000000000000)});
}

const WIDTH = 7;

const Shape = enum { dash, plus, angle, pipe, box };
const SHAPE_DASH = .{.{true} ** 4};
const SHAPE_PLUS = .{ .{ false, true, false }, .{true} ** 3, .{ false, true, false } };
const SHAPE_ANGLE = .{.{true} ** 3} ++ .{.{false} ** 2 ++ .{true}} ** 2;
const SHAPE_PIPE = .{.{true}} ** 4;
const SHAPE_BOX = .{.{true} ** 2} ** 2;
const State = enum { air, moving_piece, fixed_piece, wall };
const World = struct {
    start: usize = 1,
    width: usize = WIDTH,
    stride: usize = WIDTH + 2,
    trimmed_height: usize = 0,
    stack_height: usize = 0,
    data: ArrayListUnmanaged([WIDTH + 2]State) = .{},

    breeze: []const u8,
    next_breeze_idx: usize = 0,

    fn printWorld(world: World, comptime header: []const u8, args: anytype) void {
        const printer = log.scoped(.world).warn;
        printer(header, args);
        printSubsetWorld(world, 0, world.data.items.len);
    }

    fn printSubsetWorld(world: World, start: usize, end: usize) void {
        const printer = log.scoped(.world).warn;

        var row_idx = end;
        while (row_idx > start) : (row_idx -= 1) {
            const row = world.data.items[row_idx - 1];
            var to_print: [WIDTH + 2]u8 = undefined;

            for (row) |cell, i| to_print[i] = switch (cell) {
                .air => '.',
                .moving_piece => '@',
                .fixed_piece => '#',
                .wall => '+',
            };

            printer("{s}", .{to_print});
        }
        printer("", .{});
    }

    fn ensureHeight(world: *World) !void {
        const buffer_height = 10;
        while (world.data.items.len < world.stack_height + buffer_height) {
            try world.data.append(alloc, .{.wall} ++ (.{.air} ** WIDTH) ++ .{.wall});
        }
    }

    fn addShape(world: *World, shape: Shape) void {
        const bottom_edge = world.stack_height + 4;
        switch (shape) {
            inline else => |comptime_shape| {
                const to_add = switch (comptime_shape) {
                    .dash => SHAPE_DASH,
                    .plus => SHAPE_PLUS,
                    .angle => SHAPE_ANGLE,
                    .pipe => SHAPE_PIPE,
                    .box => SHAPE_BOX,
                };
                inline for (to_add) |row, row_offset| {
                    inline for (row) |col_set, col_offset| {
                        if (col_set) world.data.items[bottom_edge + row_offset][3 + col_offset] = .moving_piece;
                    }
                }
            },
        }
    }

    fn settle(world: *World) void {
        var moved_down = true;
        while (moved_down) : (world.next_breeze_idx += 1) {
            // After a rock appears:
            // - it alternates between being pushed by a jet of hot gas one unit (in the direction indicated by the next symbol in the jet pattern)
            if (world.breeze[world.next_breeze_idx % world.breeze.len] == '<') {
                _ = world.tryMove(.left);
            } else if (world.breeze[world.next_breeze_idx % world.breeze.len] == '>') {
                _ = world.tryMove(.right);
            } else unreachable;

            // - then falling one unit down.
            moved_down = world.tryMove(.down);
        }

        var new_stack_height: usize = 0;
        for (world.data.items) |*row| {
            var contains_piece = false;
            for (row) |*cell| {
                if (cell.* == .moving_piece) cell.* = .fixed_piece;

                if (cell.* == .fixed_piece) contains_piece = true;
            }
            if (contains_piece) new_stack_height += 1;
        }
        world.stack_height = new_stack_height;
    }

    fn tryMove(world: *World, move_dir: enum { left, down, right }) bool {
        const area_to_check = world.data.items;

        // world.printWorld("Trying to move {}", .{move_dir});

        inline for (.{ .check, .move }) |op| {
            for (area_to_check[0 .. area_to_check.len - 1]) |*row, row_idx| {
                switch (move_dir) {
                    .right, .left => {
                        if (move_dir == .right) mem.reverse(State, row);
                        defer if (move_dir == .right) mem.reverse(State, row);

                        for (row[1..]) |*cell, col_idx| if (cell.* == .moving_piece) {
                            var dest_cell = &row[col_idx]; // Already - 1 because of the slice

                            if (op == .check) {
                                if (dest_cell.* == .wall or dest_cell.* == .fixed_piece) return false;
                            } else {
                                dest_cell.* = cell.*;
                                cell.* = .air;
                            }
                        };
                    },
                    .down => {
                        var moving_row = &area_to_check[row_idx + 1];
                        for (moving_row) |*cell, col_idx| if (cell.* == .moving_piece) {
                            var dest_cell = &row[col_idx];

                            if (op == .check) {
                                if (dest_cell.* == .wall or dest_cell.* == .fixed_piece) return false;
                            } else {
                                dest_cell.* = cell.*;
                                cell.* = .air;
                            }
                        };
                    },
                }
            }
        }

        return true;
    }

    fn trimToSize(world: *World) !void {
        var trim_idx: usize = 0;
        for (world.data.items) |row, row_idx| {
            if (row_idx == 0) continue;

            const all_filled: []const State = &([_]State{.wall} ++ ([_]State{.fixed_piece} ** WIDTH) ++ [_]State{.wall});
            if (mem.eql(State, &row, all_filled)) {
                trim_idx = row_idx;
                break;
            }
        }

        const height_before = world.stack_height + world.trimmed_height;

        if (trim_idx == 0) return;

        const items = world.data.toOwnedSlice(alloc);
        defer alloc.free(items);

        try world.data.append(alloc, items[0]);
        try world.data.appendSlice(alloc, items[trim_idx + 1 ..]);
        var rows_trimmed = items.len - world.data.items.len;

        world.stack_height -= rows_trimmed;
        world.trimmed_height += rows_trimmed;

        const height_after = world.stack_height + world.trimmed_height;

        // log.warn("Trimmed {} rows, height before: {}, height after: {},  trimmed_so_far: {}", .{ rows_trimmed, height_before, height_after, world.trimmed_height });
        // world.printWorld("Trimmed from {} to {}", .{ items.len, world.data.items.len });

        debug.assert(height_before == height_after);
    }
};

fn part1(source: []const u8, turns: u64) !u64 {
    const shapes = std.meta.tags(Shape);

    var world = World{ .breeze = source };
    try world.data.append(alloc, .{.wall} ** 9);

    var step: usize = 0;
    while (step < turns) : (step += 1) {
        const new_shape = shapes[step % shapes.len];

        try world.ensureHeight();
        world.addShape(new_shape);
        // world.printWorld("Added shape {}", .{new_shape});
        world.settle();
        // world.printWorld("Settled rock {}", .{step + 1});
    }

    // 3265 high
    return world.stack_height + world.trimmed_height;
}

fn part2(source: []const u8, turns: u64) !u64 {
    const shapes = std.meta.tags(Shape);

    var world = World{ .breeze = source };
    try world.data.append(alloc, .{.wall} ** 9);

    var step: usize = 0;
    var prev_step: usize = 0;
    var prev_height: u64 = 0;
    var prev_delta: u64 = 0;
    while (step < turns) : (step += 1) {
        const new_shape = shapes[step % shapes.len];

        const next_breeze_idx = world.next_breeze_idx % world.breeze.len;
        // This is where my input loops, YMMV
        if (next_breeze_idx == 0 and new_shape == .angle) {
            // log.warn("{} {}", .{ next_breeze_idx, new_shape });
            const total_height = world.stack_height + world.trimmed_height;
            const delta = total_height - prev_height;
            if (delta == prev_delta) {
                // Zoom ahead!
                const rocks_per_loop = step - prev_step;
                while (step + rocks_per_loop < turns) {
                    step += rocks_per_loop;
                    world.trimmed_height += delta;
                }
            }
            // debug.print("step: {}, rel_height: {} - rel_delta: {}\tHeight: {} - delta: {}\n", .{ step, world.stack_height, @intCast(i64, world.stack_height) - prev_rel, total_height, total_height - prev });
            // if (world.data.items.len > 20) {
            //     world.printSubsetWorld(world.data.items.len - 15, world.data.items.len - 4);
            // } else {
            //     world.printWorld("", .{});
            // }
            prev_step = step;
            prev_height = total_height;
            prev_delta = delta;
        }

        try world.ensureHeight();
        world.addShape(new_shape);
        // world.printWorld("Added shape {}", .{new_shape});
        world.settle();
        // world.printWorld("Settled rock {}", .{step + 1});
        try world.trimToSize();
    }

    // world.printWorld("Done", .{});
    return world.stack_height + world.trimmed_height;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 1), try part1(test_input, 1));
    try std.testing.expectEqual(@as(u64, 4), try part1(test_input, 2));
    try std.testing.expectEqual(@as(u64, 6), try part1(test_input, 3));
    try std.testing.expectEqual(@as(u64, 7), try part1(test_input, 4));
    try std.testing.expectEqual(@as(u64, 9), try part1(test_input, 5));
    try std.testing.expectEqual(@as(u64, 3068), try part1(test_input, 2022));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 3068), try part2(test_input, 2022));
    try std.testing.expectEqual(@as(u64, 3100), try part2(input[0 .. input.len - 1], 2022));
    // try std.testing.expectEqual(@as(u64, 1514285714288), try part2(test_input, 1000000000000));
}

const test_input =
    \\>>><<><>><<<>><>>><<<>>><<<><<<>><>><<>>
;
