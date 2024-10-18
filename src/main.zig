const std = @import("std");
const TGA = @import("image/tga.zig");

const Allocator = std.mem.Allocator;

// fn line(
//     x0: f64,
//     y0: f64,
//     x1: f64,
//     y1: f64,
//     img: *TGA,
//     color: [3]u8
// ) void {
// }

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var tga = try TGA.init(
        allocator,
        100,
        100,
        .uncompressed_true_color
    );
    defer tga.deinit();

    tga.set(52, 41, [3]u8{ 255, 0, 0 });
    tga.flipVertically();

    // line(0, 0, 100, 100, &tga, [3]u8{ 255, 255, 255 });

    try tga.save("test.tga");
}
