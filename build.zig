const std = @import("std");

pub fn build(b: *std.Build) void {
    const ihex = b.addModule("ihex", .{
        .root_source_file = b.path("ihex.zig"),
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
            .imports = &.{
                .{ .name = "ihex", .module = ihex },
            },
        }),
    });
    b.step("test", "Run all tests").dependOn(&b.addRunArtifact(tests).step);
}
