const std = @import("std");

const Build = std.Build;

const tests = [_][]const u8{"src/image/tests.zig"};

fn attachDependencies(b: *Build, exe: *Build.Step.Compile) void {
    exe.addIncludePath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/include" });
    exe.addLibraryPath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/lib" });

    exe.addIncludePath(b.path("./deps"));
    exe.addCSourceFile(.{
        .file = b.path("./deps/glad.c"),
        .flags = &.{}
    });

    exe.addIncludePath(b.path("./tests/include"));
    exe.addCSourceFile(.{
        .file = b.path("./tests/include/stb.c"),
        .flags = &.{}
    });

    exe.linkFramework("OpenGL");
    exe.linkSystemLibrary("glfw");
}

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const stb = b.addExecutable(.{
        .name = "stb",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize
    });
    attachDependencies(b, stb);
    b.installArtifact(stb);

    const view = b.addExecutable(.{
        .name = "view",
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize
    });
    attachDependencies(b, view);
    b.installArtifact(view);

    const run_exe = b.addRunArtifact(view);
    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step = b.step("run", "View image");
    run_step.dependOn(&run_exe.step);

    const test_step = b.step("test", "Run tests");
    for (tests) |path| {
        const unit_tests = b.addTest(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize
        });

        attachDependencies(b, unit_tests);

        const run_unit_tests = b.addRunArtifact(unit_tests);

        test_step.dependOn(&run_unit_tests.step);
    }
}
