const std = @import("std");
const TGA = @import("tga.zig");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var img = try TGA.from(allocator, "tests/tga/bird.tga");
    defer img.deinit();
}
