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

const input = @embedFile("inputs/day20.txt");

const PRINT_WORLD = false;
pub const log_level = .info;

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

fn parse(source: []const u8) ![]i64 {
    var results = ArrayListUnmanaged(i64){};

    var parser = Parser{ .source = source };
    while (parser.hasMore()) : (_ = parser.line()) {
        try results.append(alloc, parser.chunk(i64).?);
    }

    return results.toOwnedSlice(alloc);
}

fn step(result_idxs: []usize, instruction: i64, instruction_idx: usize) void {
    const len_i64 = @intCast(i64, result_idxs.len);
    const rounded_instruction = instruction;

    const index = result_idxs[instruction_idx];

    var new_index = @intCast(i64, index) + rounded_instruction;
    new_index = @mod(new_index, len_i64 - 1);

    for (result_idxs) |*r| {
        if (r.* > index) r.* -= 1;
    }
    for (result_idxs) |*r| {
        if (r.* >= new_index) r.* += 1;
    }
    result_idxs[instruction_idx] = @intCast(usize, new_index);
}

fn part1(source: []const u8) !i64 {
    const instructions = try parse(source);
    var result_idxs = try alloc.alloc(usize, instructions.len);
    for (result_idxs) |*p, i| p.* = i;

    for (instructions) |instruction, instruction_idx| {
        step(result_idxs, instruction, instruction_idx);
    }

    var result = try alloc.alloc(i64, instructions.len);
    for (result_idxs) |r, i| result[r] = instructions[i];

    const index = mem.indexOfScalar(i64, result, 0).?;
    const a = result[(index + 1000) % instructions.len];
    const b = result[(index + 2000) % instructions.len];
    const c = result[(index + 3000) % instructions.len];

    // 8688 high
    return a + b + c;
}

fn part2(source: []const u8) !i64 {
    var instructions = try parse(source);
    for (instructions) |*i| i.* *= 811589153;

    var result_idxs = try alloc.alloc(usize, instructions.len);
    for (result_idxs) |*p, i| p.* = i;

    var round: usize = 0;
    while (round < 10) : (round += 1) {
        for (instructions) |instruction, instruction_idx| {
            step(result_idxs, instruction, instruction_idx);
        }
    }

    var result = try alloc.alloc(i64, instructions.len);
    for (result_idxs) |r, i| result[r] = instructions[i];

    const index = mem.indexOfScalar(i64, result, 0).?;
    const a = result[(index + 1000) % instructions.len];
    const b = result[(index + 2000) % instructions.len];
    const c = result[(index + 3000) % instructions.len];

    // 8688 high
    return a + b + c;
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 3), try part1(test_input));
}
// test "part1 detailed" {
//     var buffer = try parse(test_input);
//     try buffer.ensureUnusedCapacity(alloc, 1);
//     const instructions = try alloc.dupe(i64, buffer.items);
//
//     const expected_values = [_][7]i64{
//         .{ 2, 1, -3, 3, -2, 0, 4 },
//         .{ 1, -3, 2, 3, -2, 0, 4 },
//         .{ 1, 2, 3, -2, -3, 0, 4 },
//         .{ 1, 2, -2, -3, 0, 3, 4 },
//         .{ 1, 2, -3, 0, 3, 4, -2 },
//         .{ 1, 2, -3, 0, 3, 4, -2 },
//         .{ 1, 2, -3, 4, 0, 3, -2 },
//     };
//     for (instructions) |instruction, i| {
//         step(&buffer, instruction);
//         log.warn("{any}", .{buffer.items});
//         try std.testing.expectEqualSlices(i64, &expected_values[i], buffer.items);
//     }
// }
// test "wrapping example" {
//     var buffer_slice = [_]i64{ 4, -2, 5, 6, 7, 8, 9 };
//     var buffer = .{ .items = &buffer_slice, .capacity = 7 };
//     step(&buffer, -2);
//     log.warn("{any}", .{buffer_slice});
//     try std.testing.expectEqualSlices(i64, &.{ 4, 5, 6, 7, 8, -2, 9 }, buffer.items);
// }
// test "twice up to same index" {
//     var buffer_slice = [_]i64{ 1, 2, 8, 4, 5 };
//     var buffer = .{ .items = &buffer_slice, .capacity = 5 };
//     step(&buffer, 8);
//     log.warn("{any}", .{buffer_slice});
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, 8, 4, 5 }, buffer.items);
// }
// test "twice down to same index" {
//     var buffer_slice = [_]i64{ 1, 2, -8, 4, 5 };
//     var buffer = .{ .items = &buffer_slice, .capacity = 5 };
//     step(&buffer, -8);
//     log.warn("{any}", .{buffer_slice});
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, -8, 4, 5 }, buffer.items);
// }
// test "more than twice down" {
//     var buffer_slice = [_]i64{ 1, 2, -9, 4, 5 };
//     var buffer = .{ .items = &buffer_slice, .capacity = 5 };
//     step(&buffer, -9);
//     log.warn("{any}", .{buffer_slice});
//     try std.testing.expectEqualSlices(i64, &.{ 1, -9, 2, 4, 5 }, buffer.items);
// }
// test "one by one up to same index" {
//     var buffer_slice = [_]i64{ 7, 2, 1, 4, 5 };
//     var buffer = .{ .items = &buffer_slice, .capacity = 5 };
//     step(&buffer, 1);
//     try std.testing.expectEqualSlices(i64, &.{ 7, 2, 4, 1, 5 }, buffer.items);
//     step(&buffer, 1);
//     try std.testing.expectEqualSlices(i64, &.{ 7, 2, 4, 5, 1 }, buffer.items);
//     step(&buffer, 1);
//     try std.testing.expectEqualSlices(i64, &.{ 7, 1, 2, 4, 5 }, buffer.items);
//     step(&buffer, 1);
//     try std.testing.expectEqualSlices(i64, &.{ 7, 2, 1, 4, 5 }, buffer.items);
// }
// test "one by one down to same index" {
//     var buffer_slice = [_]i64{ 1, 2, -1, 4, 5 };
//     var buffer = .{ .items = &buffer_slice, .capacity = 5 };
//     step(&buffer, -1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, -1, 2, 4, 5 }, buffer.items);
//     step(&buffer, -1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, 4, 5, -1 }, buffer.items);
//     step(&buffer, -1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, 4, -1, 5 }, buffer.items);
//     step(&buffer, -1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, -1, 4, 5 }, buffer.items);
// }
// test "I lost my mind :(" {
//     var buffer_slice = [_]i64{ 1, 2, 1, 2, 5 };
//     var buffer = .{ .items = &buffer_slice, .capacity = 5 };
//     step(&buffer, 1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, -1, 2, 4, 5 }, buffer.items);
//     step(&buffer, 1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, 4, 5, -1 }, buffer.items);
//     step(&buffer, -1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, 4, -1, 5 }, buffer.items);
//     step(&buffer, -1);
//     try std.testing.expectEqualSlices(i64, &.{ 1, 2, -1, 4, 5 }, buffer.items);
// }
test "part2" {
    try std.testing.expectEqual(@as(i64, 1623178306), try part2(test_input));
}

const test_input =
    \\1
    \\2
    \\-3
    \\3
    \\-2
    \\0
    \\4
;
