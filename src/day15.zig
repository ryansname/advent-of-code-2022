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

const input = @embedFile("inputs/day15.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input, 2000000)});
    log.info("Part 2: {}", .{try part2(input, 4000000)});
}

const V2 = struct { x: i64, y: i64 };
const State = enum { Air, Sand, Wall, Void };
const Reading = struct { sensor: V2, beacon: V2 };

fn parse(source: []const u8) ![]Reading {
    var parser = Parser{ .source = source };

    var results = ArrayListUnmanaged(Reading){};
    errdefer results.deinit(alloc);
    while (parser.hasMore()) {
        var reading = try results.addOne(alloc);
        parser.ignore("Sensor at x=");
        reading.sensor.x = parser.chunk(i64).?;
        parser.ignore("y=");
        reading.sensor.y = parser.chunk(i64).?;

        parser.ignore("closest beacon is at x=");
        reading.beacon.x = parser.chunk(i64).?;
        parser.ignore("y=");
        reading.beacon.y = parser.chunk(i64).?;

        _ = parser.line();
    }

    return results.toOwnedSlice(alloc);
}

fn part1(source: []const u8, row: i64) !u64 {
    const readings = try parse(source);
    defer alloc.free(readings);

    var sensed_mins = try ArrayListUnmanaged(i64).initCapacity(alloc, readings.len);
    defer sensed_mins.deinit(alloc);
    var sensed_maxs = try ArrayListUnmanaged(i64).initCapacity(alloc, readings.len);
    defer sensed_maxs.deinit(alloc);

    var min_x: i64 = math.maxInt(i64);
    var max_x: i64 = math.minInt(i64);
    for (readings) |r| {
        const clear_distance = try math.absInt(r.beacon.x - r.sensor.x) + try math.absInt(r.beacon.y - r.sensor.y);

        const distance_sensor_to_row = try math.absInt(row - r.sensor.y);
        const distance_on_axis = clear_distance - distance_sensor_to_row;

        // A distance_on_axis of 0 indicates that it's at the corner
        if (distance_on_axis < 0) continue;

        const this_min = r.sensor.x - distance_on_axis;
        const this_max = r.sensor.x + distance_on_axis;
        // log.warn("Sensor at {}, {}, reaches from {} to {} (inclusive), {} {}", .{ r.sensor.x, r.sensor.y, this_min, this_max, distance_sensor_to_row, distance_on_axis });

        // Otherwise we know that there's no beacons in this range
        min_x = @min(min_x, this_min);
        max_x = @max(max_x, this_max);
        sensed_mins.appendAssumeCapacity(this_min);
        sensed_maxs.appendAssumeCapacity(this_max);
    }

    var impossible_count: u64 = 0;
    var check_x: i64 = min_x;
    while (check_x < max_x) {
        const prev_x = check_x;
        defer debug.assert(prev_x != check_x);

        // Find any sensor which is in range of this point
        // Otherwise if there is no beacon, find the first min_x which is greater than check_x
        const reading_idx = for (sensed_mins.items) |min, i| {
            // log.warn("{} <= {} and {} <= {}", .{ min, check_x, check_x, sensed_maxs.items[i] });
            if (min <= check_x and check_x <= sensed_maxs.items[i]) break i;
        } else {
            var nearest_min: i64 = math.maxInt(i64);
            for (sensed_mins.items) |min| {
                nearest_min = @min(nearest_min, min);
            }
            // log.warn("Skipping from {} to {}", .{ check_x, nearest_min });
            check_x = nearest_min;
            continue;
        };

        // For that beacon count add all the cells between its max_x and check_x
        const max = sensed_maxs.items[reading_idx];
        // log.warn(
        //     "Adding points between {} and {} (inclusive) from sensor at {} which found a beacon at {}",
        //     .{
        //         check_x,
        //         max,
        //         readings[reading_idx].sensor,
        //         readings[reading_idx].beacon,
        //     },
        // );
        impossible_count += @intCast(u64, max - check_x) + 1; // Add one due to the range being full open (the range 1-1 should have len 1)

        // If there is a beacon at the start or end (which are the only possible places) subtract one
        inline for (.{ check_x, max }) |test_x| {
            for (readings) |r| {
                if (r.beacon.y == row and r.beacon.x == test_x) {
                    // log.warn("Excluding actual beacon at {}", .{r.beacon});
                    impossible_count -= 1;
                    break;
                }
            }
        }

        check_x = max + 1;
    }

    return impossible_count;
}

fn getColumnWithScannedGap(fast_alloc: std.mem.Allocator, readings: []Reading, row: i64, col_min: i64, col_max: i64) !?i64 {
    var sensed_mins = try ArrayListUnmanaged(i64).initCapacity(fast_alloc, readings.len);
    defer sensed_mins.deinit(alloc);
    var sensed_maxs = try ArrayListUnmanaged(i64).initCapacity(fast_alloc, readings.len);
    defer sensed_maxs.deinit(alloc);

    for (readings) |r| {
        const clear_distance = try math.absInt(r.beacon.x - r.sensor.x) + try math.absInt(r.beacon.y - r.sensor.y);

        const distance_sensor_to_row = try math.absInt(row - r.sensor.y);
        const distance_on_axis = clear_distance - distance_sensor_to_row;

        // A distance_on_axis of 0 indicates that it's at the corner
        if (distance_on_axis < 0) continue;

        // Otherwise we know that there's no beacons in this range
        const this_min = r.sensor.x - distance_on_axis;
        const this_max = r.sensor.x + distance_on_axis;

        sensed_mins.appendAssumeCapacity(this_min);
        sensed_maxs.appendAssumeCapacity(this_max);
    }

    var check_x: i64 = col_min;
    while (check_x <= col_max) {
        const sensor_idx = for (sensed_mins.items) |min, i| {
            if (min <= check_x and check_x <= sensed_maxs.items[i]) break i;
        } else {
            return check_x;
        };

        check_x = sensed_maxs.items[sensor_idx] + 1;
    }

    return null;
}

fn part2(source: []const u8, bounding_box_len: u63) !u64 {
    const readings = try parse(source);
    defer alloc.free(readings);

    var progress = std.Progress{
        .dont_print_on_dumb = true,
    };
    var node = progress.start("Scanning rows to find hole", bounding_box_len);
    defer node.end();

    var fast_alloc = std.heap.stackFallback(1_000_000, alloc);
    
    var row: i64 = 0;
    const col = while (row < bounding_box_len) : (row += 1) {
        defer node.completeOne();
        if (try getColumnWithScannedGap(fast_alloc.get(), readings, row, 0, bounding_box_len)) |c| break c;
    } else unreachable;

    return @intCast(u64, col * 4000000 + row);
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 26), try part1(test_input, 10));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 56000011), try part2(test_input, 20));
}

const test_input =
    \\Sensor at x=2, y=18: closest beacon is at x=-2, y=15
    \\Sensor at x=9, y=16: closest beacon is at x=10, y=16
    \\Sensor at x=13, y=2: closest beacon is at x=15, y=3
    \\Sensor at x=12, y=14: closest beacon is at x=10, y=16
    \\Sensor at x=10, y=20: closest beacon is at x=10, y=16
    \\Sensor at x=14, y=17: closest beacon is at x=10, y=16
    \\Sensor at x=8, y=7: closest beacon is at x=2, y=10
    \\Sensor at x=2, y=0: closest beacon is at x=2, y=10
    \\Sensor at x=0, y=11: closest beacon is at x=2, y=10
    \\Sensor at x=20, y=14: closest beacon is at x=25, y=17
    \\Sensor at x=17, y=20: closest beacon is at x=21, y=22
    \\Sensor at x=16, y=7: closest beacon is at x=15, y=3
    \\Sensor at x=14, y=3: closest beacon is at x=15, y=3
    \\Sensor at x=20, y=1: closest beacon is at x=15, y=3
;
