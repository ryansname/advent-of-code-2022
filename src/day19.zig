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

const input = @embedFile("inputs/day19.txt");

const PRINT_WORLD = false;
pub const log_level = .info;

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

const State = struct {
    ore_count: u64 = 0,
    clay_count: u64 = 0,
    obsidian_count: u64 = 0,
    geode_count: u64 = 0,
    ore_robots: u64 = 0,
    clay_robots: u64 = 0,
    obsidian_robots: u64 = 0,
    geode_robots: u64 = 0,
};
const Blueprint = struct {
    id: u8,
    ore_robot_cost: struct { ore: u8 },
    clay_robot_cost: struct { ore: u8 },
    obsidian_robot_cost: struct { ore: u8, clay: u8 },
    geode_robot_cost: struct { ore: u8, obsidian: u8 },

    max_ore_per_robot: u8,
    max_clay_per_robot: u8,
};

fn parse(source: []const u8) ![]Blueprint {
    var blueprints = ArrayListUnmanaged(Blueprint){};

    var parser = Parser{ .source = source };
    while (parser.hasMore()) : (_ = parser.line()) {
        var blueprint = try blueprints.addOne(alloc);

        // Blueprint 1: Each ore robot costs 4 ore. Each clay robot costs 4 ore. Each obsidian robot costs 4 ore and 5 clay. Each geode robot costs 3 ore and 15 obsidian.
        parser.ignore("Blueprint ");
        blueprint.id = parser.chunk(u8).?;

        parser.ignore("Each ore robot costs ");
        blueprint.ore_robot_cost.ore = parser.chunk(u8).?;
        parser.ignore("ore. ");

        parser.ignore("Each clay robot costs ");
        blueprint.clay_robot_cost.ore = parser.chunk(u8).?;
        parser.ignore("ore. ");

        parser.ignore("Each obsidian robot costs ");
        blueprint.obsidian_robot_cost.ore = parser.chunk(u8).?;
        parser.ignore("ore and ");
        blueprint.obsidian_robot_cost.clay = parser.chunk(u8).?;
        parser.ignore("clay. ");

        parser.ignore("Each geode robot costs ");
        blueprint.geode_robot_cost.ore = parser.chunk(u8).?;
        parser.ignore("ore and ");
        blueprint.geode_robot_cost.obsidian = parser.chunk(u8).?;
        parser.ignore("obsidian.");

        blueprint.max_ore_per_robot = math.max(
            math.max(
                blueprint.ore_robot_cost.ore,
                blueprint.clay_robot_cost.ore,
            ),
            math.max(
                blueprint.obsidian_robot_cost.ore,
                blueprint.geode_robot_cost.ore,
            ),
        );
    }

    return blueprints.toOwnedSlice(alloc);
}

fn collect(state: *State) void {
    state.ore_count += state.ore_robots;
    state.clay_count += state.clay_robots;
    state.obsidian_count += state.obsidian_robots;
    state.geode_count += state.geode_robots;
}

fn canBuy(state: State, robot_cost: anytype) bool {
    const CostType = @TypeOf(robot_cost);

    inline for (.{ "ore", "clay", "obsidian" }) |resource| {
        if (@hasField(CostType, resource) and @field(state, resource ++ "_count") < @field(robot_cost, resource)) return false;
    }

    return true;
}

fn buy(state: *State, robot_cost: anytype) void {
    const CostType = @TypeOf(robot_cost);

    inline for (.{ "ore", "clay", "obsidian" }) |resource| {
        if (@hasField(CostType, resource)) @field(state, resource ++ "_count") -= @field(robot_cost, resource);
    }
}

fn simulate(blueprint: Blueprint, minutes_passed: u32, minutes_max: u32, state: State) State {
    if (minutes_passed >= minutes_max) return state;

    var best_state = state;

    // Thanks for the optimisation Harry!
    inline for (.{ "geode", "obsidian", "clay", "ore" }) |resource| {
        if ((mem.eql(u8, "ore", resource) and state.ore_robots >= blueprint.max_ore_per_robot) or
            (mem.eql(u8, "clay", resource) and state.clay_robots >= blueprint.obsidian_robot_cost.clay) or
            (mem.eql(u8, "obsidian", resource) and state.obsidian_robots >= blueprint.geode_robot_cost.obsidian))
        {} else {
            var next_minutes = minutes_passed + 1;
            var test_state = state;
            const cost = @field(blueprint, resource ++ "_robot_cost");
            while (!canBuy(test_state, cost)) { //  and ()) {
                collect(&test_state);
                next_minutes += 1;
                if (next_minutes >= minutes_max) break;
            }

            if (next_minutes <= minutes_max) {
                collect(&test_state);

                if (canBuy(test_state, cost)) {
                    buy(&test_state, cost);
                    @field(test_state, resource ++ "_robots") += 1;
                }
                test_state = simulate(blueprint, next_minutes, minutes_max, test_state);
            }
            if (test_state.geode_count > best_state.geode_count) best_state = test_state;
        }
    }

    return best_state;
}

fn part1(source: []const u8) !u64 {
    const blueprints = try parse(source);
    var result: u64 = 0;

    var initial_state = State{};
    // Start with one ore robot
    initial_state.ore_robots += 1;

    for (blueprints) |blueprint| {
        const best_state = simulate(blueprint, 0, 24, initial_state);
        log.warn("Best result: {}", .{best_state});
        result += blueprint.id * best_state.geode_count;
    }

    return result;
}

fn part2(source: []const u8) !u64 {
    const blueprints = try parse(source);
    var result: u64 = 1;

    var initial_state = State{};
    // Start with one ore robot
    initial_state.ore_robots += 1;

    for (blueprints[0..@min(3, blueprints.len)]) |blueprint| {
        const best_state = simulate(blueprint, 0, 32, initial_state);
        log.warn("Best result: {}", .{best_state});
        result *= best_state.geode_count;
    }

    return result;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 33), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 56 * 62), try part2(test_input));
}

const test_input =
    \\Blueprint 1: Each ore robot costs 4 ore. Each clay robot costs 2 ore. Each obsidian robot costs 3 ore and 14 clay. Each geode robot costs 2 ore and 7 obsidian.
    \\Blueprint 2: Each ore robot costs 2 ore. Each clay robot costs 3 ore. Each obsidian robot costs 3 ore and 8 clay. Each geode robot costs 3 ore and 12 obsidian.
;
