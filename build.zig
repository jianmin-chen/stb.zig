const std = @import("std");

const Build = std.Build;

const out = [_][]const u8{"stb", "view"};
const inp = [_][]const u8{"src/main.zig", "src/view.zig"};

fn attachDependencies(b: *Build, exe: *Build.Step.Compile) void {
    exe.addIncludePath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/include" });
    exe.addLibraryPath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/lib" });
    exe.addCSourceFile(.{
        .file = b.path("./deps/glad.c"),
        .flags = &.{}
    });
    exe.addIncludePath(b.path("./deps"));
    exe.addCSourceFile(.{
        .file = b.path("./tests/include/stb.c"),
        .flags = &.{}
    });
    exe.addIncludePath(b.path("./tests/include"));
    exe.linkFramework("OpenGL");
    exe.linkSystemLibrary("glfw");
}

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    for (inp, 0..) |path, idx| {
        const exe = b.addExecutable(.{
            .name = out[idx],
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize
        });

        attachDependencies(b, exe);

        b.installArtifact(exe);
    }
}
