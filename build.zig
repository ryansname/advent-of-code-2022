const fs = std.fs;
const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const test_step = b.step("test", "Run unit tests");
    const test_all_step = b.step("test-all", "Run all unit tests");
    var latest_test_step: ?*std.build.LibExeObjStep = null;

    const run_step = b.step("run", "Run the latest modified puzzle");
    const run_all_step = b.step("run-all", "Run all puzzles");
    var latest_run_step: ?*std.build.RunStep = null;

    var cwd = fs.cwd();

    var latest_mtime: i128 = 0;
    comptime var i: u8 = 1;
    inline while (i <= 25) : (i += 1) {
        const i_string = [_]u8{i + '0'};
        const source_file = "src/day" ++ i_string ++ ".zig";

        const day_stat = cwd.statFile(source_file);

        if (day_stat) |stat| {
            const day_build = addSingleDay(b, target, mode, i_string, source_file);
            test_all_step.dependOn(&day_build.exe_tests.step);
            run_all_step.dependOn(&day_build.run_cmd.step);

            if (stat.mtime > latest_mtime) {
                latest_run_step = day_build.run_cmd;
                latest_test_step = day_build.exe_tests;
                latest_mtime = stat.mtime;
            }
        } else |err| {
            if (err != error.FileNotFound) {
                std.debug.panic("Error opening file " ++ source_file ++ ": {}", .{err});
            }
        }
    }
    run_step.dependOn(&latest_run_step.?.step);
    test_step.dependOn(&latest_test_step.?.step);
}

fn addSingleDay(
    b: *std.build.Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
    i_string: anytype,
    source_file: anytype,
) struct {
    exe_tests: *std.build.LibExeObjStep,
    run_cmd: *std.build.RunStep,
} {
    const exe = b.addExecutable("advent-of-code-2022-day-" ++ i_string, source_file);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run-" ++ i_string, "Run the puzzle from day " ++ i_string);
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(source_file);
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    return .{
        .exe_tests = exe_tests,
        .run_cmd = run_cmd,
    };
}
