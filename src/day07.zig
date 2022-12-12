const debug = std.debug;
const std = @import("std");
const log = std.log;
const math = std.math;
const mem = std.mem;

const Parser = @import("lib/parse1.zig").Parser;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const input = @embedFile("inputs/day7.txt");

pub fn main() !void {
    log.info("{s}", .{@src().file});
    log.info("Part 1: {}", .{try part1(input)});
    log.info("Part 2: {}", .{try part2(input)});
}

fn part1(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var cwd = std.ArrayList(u8).init(alloc);
    var dir_stack = std.ArrayList([]const u8).init(alloc);
    try dir_stack.append("");
    var files = std.StringHashMap(u64).init(alloc);

    while (parser.hasMore()) {
        var line = parser.subparse("\n").?;
        switch (line.source[0]) {
            '$' => switch (line.source[2]) {
                'c' => {
                    if (line.source[5] == '/') {
                        dir_stack.shrinkRetainingCapacity(1);
                    } else if (line.source[5] == '.') {
                        debug.assert(line.source[6] == '.');
                        _ = dir_stack.pop();
                    } else {
                        try dir_stack.append(line.source[5..]);
                    }
                }, // $ cd dirname
                'l' => {
                    // Nothing we'll be getting other inputs
                }, // ls
                else => unreachable,
            },
            'd' => {}, // new dir
            '0'...'9' => {
                const size = try line.takeType(u64, " ") orelse unreachable;
                const filename = try line.takeType([]const u8, "\n") orelse unreachable;
                _ = filename;

                defer cwd.shrinkRetainingCapacity(0);
                for (dir_stack.items) |dir| {
                    try cwd.appendSlice(dir);
                    try cwd.append('/');
                    var get_or_put_result = try files.getOrPut(try alloc.dupe(u8, cwd.items)); // LEAK
                    if (get_or_put_result.found_existing) {
                        get_or_put_result.value_ptr.* += size;
                    } else {
                        get_or_put_result.value_ptr.* = size;
                    }
                }
            }, // new file
            else => unreachable,
        }
    }

    var result: u64 = 0;
    var iter = files.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.* <= 100000) {
            result += entry.value_ptr.*;
        }
        // log.warn("{s} has size {}", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    return result;
}

fn part2(source: []const u8) !u64 {
    var parser = Parser{ .source = source };

    var cwd = std.ArrayList(u8).init(alloc);
    var dir_stack = std.ArrayList([]const u8).init(alloc);
    try dir_stack.append("");
    var files = std.StringHashMap(u64).init(alloc);

    while (parser.hasMore()) {
        var line = parser.subparse("\n").?;
        switch (line.source[0]) {
            '$' => switch (line.source[2]) {
                'c' => {
                    if (line.source[5] == '/') {
                        dir_stack.shrinkRetainingCapacity(1);
                    } else if (line.source[5] == '.') {
                        debug.assert(line.source[6] == '.');
                        _ = dir_stack.pop();
                    } else {
                        try dir_stack.append(line.source[5..]);
                    }
                }, // $ cd dirname
                'l' => {
                    // Nothing we'll be getting other inputs
                }, // ls
                else => unreachable,
            },
            'd' => {}, // new dir
            '0'...'9' => {
                const size = try line.takeType(u64, " ") orelse unreachable;
                const filename = try line.takeType([]const u8, "\n") orelse unreachable;
                _ = filename;

                defer cwd.shrinkRetainingCapacity(0);
                for (dir_stack.items) |dir| {
                    try cwd.appendSlice(dir);
                    try cwd.append('/');
                    var get_or_put_result = try files.getOrPut(try alloc.dupe(u8, cwd.items)); // LEAK
                    if (get_or_put_result.found_existing) {
                        get_or_put_result.value_ptr.* += size;
                    } else {
                        get_or_put_result.value_ptr.* = size;
                    }
                }
            }, // new file
            else => unreachable,
        }
    }

    const total_space = 70000000;
    const required_space = 30000000;
    const used_space = files.get("/").?;
    const free_space = total_space - used_space;
    const space_to_free = required_space - free_space;
    // log.info("Total: {}, Used: {}, Free: {}", .{ total_space, used_space, total_space - used_space });

    var result: u64 = math.maxInt(u64);
    var iter = files.iterator();
    while (iter.next()) |entry| {
        // If deleting this dir would free enough space
        const this_dir_size = entry.value_ptr.*;
        if (this_dir_size >= space_to_free) {
            // And if deleting this dir frees less space than the current result
            if (this_dir_size < result) result = this_dir_size;
        }
        // log.warn("{s} has size {}", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    return result;
}

test "part1" {
    try std.testing.expectEqual(@as(u64, 95437), try part1(test_input));
}
test "part2" {
    try std.testing.expectEqual(@as(u64, 24933642), try part2(test_input));
}

const test_input =
    \\$ cd /
    \\$ ls
    \\dir a
    \\14848514 b.txt
    \\8504156 c.dat
    \\dir d
    \\$ cd a
    \\$ ls
    \\dir e
    \\29116 f
    \\2557 g
    \\62596 h.lst
    \\$ cd e
    \\$ ls
    \\584 i
    \\$ cd ..
    \\$ cd ..
    \\$ cd d
    \\$ ls
    \\4060174 j
    \\8033020 d.log
    \\5626152 d.ext
    \\7214296 k
;
