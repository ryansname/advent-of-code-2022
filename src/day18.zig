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

const input = @embedFile("inputs/day18.txt");

const PRINT_WORLD = false;

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const World = struct {
    start: usize,
    dim: usize,
    /// From 0,0,0 to 1,0,0
    x_stride: usize,
    /// From 0,0,0 to 0,1,0
    y_stride: usize,
    /// From 0,0,0 to 0,0,1
    z_stride: usize,
    data: []bool,
    water: []bool,

    fn init(max_dim: u32) !World {
        const dim_for_alloc = max_dim + 2;
        const data = try alloc.alloc(bool, dim_for_alloc * dim_for_alloc * dim_for_alloc);
        errdefer alloc.free(data);
        const water = try alloc.alloc(bool, data.len);
        errdefer alloc.free(water);
        mem.set(bool, data, false);
        mem.set(bool, water, false);

        const x_stride = 1;
        const y_stride = dim_for_alloc;
        const z_stride = dim_for_alloc * dim_for_alloc;
        return World{
            .start = x_stride + y_stride + z_stride,
            .dim = max_dim,
            .x_stride = x_stride,
            .y_stride = y_stride,
            .z_stride = z_stride,
            .data = data,
            .water = water,
        };
    }

    fn coordToIndex(world: World, x: usize, y: usize, z: usize) usize {
        return world.start +
            world.x_stride * x +
            world.y_stride * y +
            world.z_stride * z;
    }
};

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };
    const world_size = 25; // By inspection, sue me

    var surface_area: u64 = 0;
    var world = try World.init(world_size);
    while (parser.hasMore()) : (_ = parser.line()) {
        const x = parser.chunk(u8).?;
        const y = parser.chunk(u8).?;
        const z = parser.chunk(u8).?;

        const idx = world.coordToIndex(x, y, z);
        world.data[idx] = true;

        surface_area += 6;

        inline for (.{ world.x_stride, world.y_stride, world.z_stride }) |delta| {
            inline for (.{ math.add, math.sub }) |op| {
                const idx2 = try op(usize, idx, delta);
                if (world.data[idx2]) surface_area -= 2;
            }
        }
    }
    return surface_area;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };
    const world_size = 25; // By inspection, sue me

    var surface_area: u64 = 0;
    var world = try World.init(world_size);
    while (parser.hasMore()) : (_ = parser.line()) {
        const x = parser.chunk(u8).?;
        const y = parser.chunk(u8).?;
        const z = parser.chunk(u8).?;

        const idx = world.coordToIndex(x, y, z);
        world.data[idx] = true;

        surface_area += 6;

        inline for (.{ world.x_stride, world.y_stride, world.z_stride }) |delta| {
            inline for (.{ math.add, math.sub }) |op| {
                const idx2 = try op(usize, idx, delta);
                if (world.data[idx2]) surface_area -= 2;
            }
        }
    }

    // Start at 0,0,0, we'll mark reachable nodes as water
    const idx: usize = world.start;
    world.water[idx] = true;

    var changed = true;

    while (changed) {
        changed = false;
        var z: usize = 0;
        while (z < world.dim) : (z += 1) {
            const idx_z = idx + z * world.z_stride;

            var y: usize = 0;
            while (y < world.dim) : (y += 1) {
                const idx_zy = idx_z + y * world.y_stride;

                var x: usize = 0;
                next_idx: while (x < world.dim) : (x += 1) {
                    const idx_zyx = idx_zy + x * world.x_stride;

                    // If I am lava, I am not water
                    if (world.data[idx_zyx]) continue;

                    // If I am water, I am already water
                    if (world.water[idx_zyx]) continue;

                    // If a neighbour is water, so am I
                    inline for (.{ world.x_stride, world.y_stride, world.z_stride }) |delta| {
                        inline for (.{ math.add, math.sub }) |op| {
                            const idx2 = try op(usize, idx_zyx, delta);
                            if (world.water[idx2]) {
                                world.water[idx_zyx] = true;
                                changed = true;
                                continue :next_idx;
                            }
                        }
                    }
                }
            }
        }
    }

    // Finally fill any non-water in as lava
    var z: usize = 0;
    while (z < world.dim) : (z += 1) {
        const idx_z = idx + z * world.z_stride;

        var y: usize = 0;
        while (y < world.dim) : (y += 1) {
            const idx_zy = idx_z + y * world.y_stride;

            var x: usize = 0;
            next_idx: while (x < world.dim) : (x += 1) {
                const idx_zyx = idx_zy + x * world.x_stride;

                // If I am not water, I am lava
                if (!world.data[idx_zyx] and !world.water[idx_zyx]) {
                    world.data[idx_zyx] = true;
                    surface_area += 6;

                    inline for (.{ world.x_stride, world.y_stride, world.z_stride }) |delta| {
                        inline for (.{ math.add, math.sub }) |op| {
                            const idx2 = try op(usize, idx_zyx, delta);
                            if (world.data[idx2]) {
                                surface_area -= 2;
                            }
                        }
                    }
                    continue :next_idx;
                }
            }
        }
    }

    return surface_area;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 64), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 58), try part2(test_input));
}

const test_input =
    \\2,2,2
    \\1,2,2
    \\3,2,2
    \\2,1,2
    \\2,3,2
    \\2,2,1
    \\2,2,3
    \\2,2,4
    \\2,2,6
    \\1,2,5
    \\3,2,5
    \\2,1,5
    \\2,3,5
;
