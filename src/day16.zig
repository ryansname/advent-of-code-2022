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
const slow_alloc = gpa.allocator();
const fast_alloc = std.heap.stackFallback(10_000, slow_alloc);

const alloc = gpa.allocator();

const input = @embedFile("inputs/day16.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const KEY_SPACE = 26 * 26;

fn keyToIndex(key: *const [2]u8) usize {
    return (@as(usize, key[0]) - 'A') * 26 + (key[1] - 'A');
}

fn indexToKey(index: usize) [2]u8 {
    var result = [2]u8{ 0, 0 };

    result[0] = @intCast(u8, @divFloor(index, 26));
    result[1] = @intCast(u8, index % 26);
    debug.assert(result[0] * 26 + result[1] == index);

    for (result) |*v| v.* += 'A';
    return result;
}

const UNKNOWN_DISTANCE = math.maxInt(u8);
const World = struct {
    useful_nodes: BoundedArray(usize, KEY_SPACE) = .{},
    flow_rates: [KEY_SPACE]u8 = [_]u8{0} ** KEY_SPACE,
    distances: [KEY_SPACE][KEY_SPACE]u8 = .{.{UNKNOWN_DISTANCE} ** KEY_SPACE} ** KEY_SPACE,
};

fn parse(source: []const u8) World {
    var parser = Parser{ .source = source };
    var world = World{};

    while (parser.hasMore()) : (_ = parser.line()) {
        parser.ignore("Valve ");
        const key = parser.chunk([]const u8).?;
        const index = keyToIndex(key[0..2]);

        parser.ignore("has flow rate=");
        const rate = parser.chunk(u8).?;
        world.flow_rates[index] = rate;
        if (rate > 0 or index == 0) world.useful_nodes.appendAssumeCapacity(index);

        _ = parser.chunk([]const u8); // take "tunnels" as chunk because sometimes it's singular
        _ = parser.chunk([]const u8); // "lead" vs "leads"
        _ = parser.chunk([]const u8); // to
        _ = parser.chunk([]const u8); // "valve" vs "valves"

        world.distances[index][index] = 0;
        while (parser.chunk([]const u8)) |neighbour| {
            const neighbour_idx = keyToIndex(neighbour[0..2]);
            world.distances[index][neighbour_idx] = 1;
        }
    }

    return world;
}

fn populateIndirectNeighbours(world: *World) !void {
    var buf1 = ArrayListUnmanaged(usize){};
    var buf2 = ArrayListUnmanaged(usize){};

    for (world.useful_nodes.slice()) |useful_node_idx| {
        // log.warn("Computing ditstance to nodes from {s} to other useful nodes", .{indexToKey(useful_node_idx)});

        defer buf1.shrinkRetainingCapacity(0);
        defer buf2.shrinkRetainingCapacity(0);

        var to_check = &buf1;
        var fringe = &buf2;

        var distances = &world.distances[useful_node_idx];
        for (distances) |distance, idx| {
            if (distance == 1) try to_check.append(alloc, idx);
        }

        var distance: u8 = 1;
        while (to_check.items.len > 0) : (distance += 1) {
            while (to_check.popOrNull()) |check_idx| {
                distances[check_idx] = distance;

                for (world.distances[check_idx]) |neighbour_distance, check_neighbour_idx| {
                    if (neighbour_distance == 1 and distances[check_neighbour_idx] == UNKNOWN_DISTANCE) {
                        try fringe.append(alloc, check_neighbour_idx);
                    }
                }
            }

            const temp = to_check;
            to_check = fringe;
            fringe = temp;
        }
    }

    for (world.useful_nodes.slice()) |useful_node_idx| for (world.useful_nodes.slice()) |dest_idx| {
        const distance = world.distances[useful_node_idx][dest_idx];
        world.distances[useful_node_idx][0] = 250;
        if (distance == UNKNOWN_DISTANCE) continue;
        // log.warn("Distance from {s} to {s} = {}", .{ indexToKey(useful_node_idx), indexToKey(dest_idx), distance });
    };
}

fn solveForWorld1(world: *World, here_idx: usize, score_so_far: u64, time_remaining: u32, score_per_time: u64, enabled_flags: []bool) u64 {
    const distances = world.distances[here_idx];

    var best_score: u64 = score_so_far + time_remaining * score_per_time;
    for (world.useful_nodes.slice()) |useful_node_idx| if (useful_node_idx != here_idx and !enabled_flags[useful_node_idx]) {
        // If there's enough time to get to the node and activate it
        const time_to_activate_node = distances[useful_node_idx] + 1;
        if (time_remaining > time_to_activate_node) {
            enabled_flags[useful_node_idx] = true;
            defer enabled_flags[useful_node_idx] = false;

            const score = solveForWorld1(
                world,
                useful_node_idx,
                score_so_far + time_to_activate_node * score_per_time,
                time_remaining - time_to_activate_node,
                score_per_time + world.flow_rates[useful_node_idx],
                enabled_flags,
            );
            best_score = @max(best_score, score);
        }
    };

    return best_score;
}

fn part1(source: []const u8) !u64 {
    var world = parse(source);
    try populateIndirectNeighbours(&world);

    var enabled_flags = try alloc.alloc(bool, KEY_SPACE);
    defer alloc.free(enabled_flags);
    enabled_flags[0] = true;

    mem.set(bool, enabled_flags, false);
    return solveForWorld1(&world, 0, 0, 30, 0, enabled_flags);
}

const Actor = struct {
    dest_idx: usize,
    time_remaining: u32,

    fn step(self: Actor, steps: u32) Actor {
        return .{ .dest_idx = self.dest_idx, .time_remaining = self.time_remaining - steps };
    }
};
fn solveForWorld2(world: *World, me: Actor, elephant: Actor, score_so_far: u64, time_remaining: u32, enabled_flags: []bool) u64 {
    inline for (.{ me, elephant }) |actor, idx| {
        if (actor.time_remaining == 0) {
            const new_score = score_so_far + time_remaining * world.flow_rates[actor.dest_idx];

            var best_score: usize = new_score;
            for (world.useful_nodes.slice()) |useful_node_idx| if (!enabled_flags[useful_node_idx]) {
                enabled_flags[useful_node_idx] = true;
                defer enabled_flags[useful_node_idx] = false;

                const distances = &world.distances;
                const time_to_node = distances[actor.dest_idx][useful_node_idx];

                if (time_to_node > time_remaining) continue;

                const next_actor = .{
                    .dest_idx = useful_node_idx,
                    .time_remaining = time_to_node + 1,
                };

                const score = solveForWorld2(
                    world,
                    if (idx == 0) next_actor else me,
                    if (idx == 0) elephant else next_actor,
                    new_score,
                    time_remaining,
                    enabled_flags,
                );
                best_score = @max(best_score, score);
            };

            const next_actor = .{
                .dest_idx = 0,
                .time_remaining = math.maxInt(u32),
            };
            const do_nothing_score = solveForWorld2(
                world,
                if (idx == 0) next_actor else me,
                if (idx == 0) elephant else next_actor,
                new_score,
                time_remaining,
                enabled_flags,
            );

            return @max(best_score, do_nothing_score);
        }
    }

    if (time_remaining == 0) {
        return score_so_far;
    }

    // log.warn("{any}", .{enabled_flags});
    const steps = math.min3(time_remaining, me.time_remaining, elephant.time_remaining);
    return solveForWorld2(
        world,
        me.step(steps),
        elephant.step(steps),
        score_so_far,
        time_remaining - steps,
        enabled_flags,
    );
}

fn solveForWorld3(world: *World, here_idx: usize, score_so_far: u64, time_remaining: u32, score_per_time: u64, enabled_flags: []bool, total_time: u32) u64 {
    const distances = world.distances[here_idx];

    const score_at_end = score_so_far + time_remaining * score_per_time;
    var best_score: u64 = score_at_end + if (total_time > 0) solveForWorld3(world, 0, 0, total_time, 0, enabled_flags, 0) else 0;
    for (world.useful_nodes.slice()) |useful_node_idx| if (useful_node_idx != here_idx and !enabled_flags[useful_node_idx]) {
        // If there's enough time to get to the node and activate it
        const time_to_activate_node = distances[useful_node_idx] + 1;
        if (time_remaining > time_to_activate_node) {
            enabled_flags[useful_node_idx] = true;
            defer enabled_flags[useful_node_idx] = false;

            const score = solveForWorld3(
                world,
                useful_node_idx,
                score_so_far + time_to_activate_node * score_per_time,
                time_remaining - time_to_activate_node,
                score_per_time + world.flow_rates[useful_node_idx],
                enabled_flags,
                total_time,
            );

            best_score = @max(best_score, score);
        }
    };

    return best_score;
}

fn part2(source: []const u8) !u64 {
    var world = parse(source);
    try populateIndirectNeighbours(&world);

    var enabled_flags = try alloc.alloc(bool, KEY_SPACE);
    defer alloc.free(enabled_flags);

    mem.set(bool, enabled_flags, false);
    enabled_flags[0] = true;

    // 2827 too low
    // 2833 nope
    // 2834 nope
    // 2835 nope
    // 2836 nope
    // 2837 nope
    // 2838 yay...
    // 2839 too high
    const time = 26;
    return solveForWorld3(
        &world,
        0,
        0,
        time,
        0,
        enabled_flags,
        time,
    );
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 1651), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 1707), try part2(test_input));
}

const test_input =
    \\Valve AA has flow rate=0; tunnels lead to valves DD, II, BB
    \\Valve BB has flow rate=13; tunnels lead to valves CC, AA
    \\Valve CC has flow rate=2; tunnels lead to valves DD, BB
    \\Valve DD has flow rate=20; tunnels lead to valves CC, AA, EE
    \\Valve EE has flow rate=3; tunnels lead to valves FF, DD
    \\Valve FF has flow rate=0; tunnels lead to valves EE, GG
    \\Valve GG has flow rate=0; tunnels lead to valves FF, HH
    \\Valve HH has flow rate=22; tunnel leads to valve GG
    \\Valve II has flow rate=0; tunnels lead to valves AA, JJ
    \\Valve JJ has flow rate=21; tunnel leads to valve II
;
