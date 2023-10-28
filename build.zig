const std = @import("std");

pub fn build(b: *std.Build) void {
    // const target = b.standardTargetOptions(.{});
    // const mode = b.standardOptimizeOption(.{});

    const ihex = b.addModule("ihex", .{
        .source_file = .{ .path = "ihex.zig" },
    });
    _ = ihex;

    // const tests = b.addTest(.{
    //     .root_source_file = .{ .path = "tests.zig"},
    //     .target = target,
    //     .optimize = mode,
    // });
    // tests.addModule("ihex", ihex);
    // const run_tests = b.addRunArtifact(tests)
    // const test_step = b.step("test", "Run all tests");
    // test_step.dependOn(&run_tests.step);
}
