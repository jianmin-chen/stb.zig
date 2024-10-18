const c = @cImport({
    @cInclude("stb_image.h");
});
const std = @import("std");

const TGA = @import("tga.zig");

const Allocator = std.mem.Allocator;
const allocator = std.testing.allocator;
const expect = std.testing.expect;

fn testTGAGrayscale(path: []const u8) !void {
    var width: c_int = 0;
    var height: c_int = 0;
    var nr_channels: c_int = 0;

    c.stbi_set_flip_vertically_on_load(1);
    const img = c.stbi_load(@ptrCast(path), &width, &height, &nr_channels, 0);
    defer c.stbi_image_free(img);

    const len: usize = 3 * @as(usize, @intCast(width)) * @as(usize, @intCast(height));
    const expected = img[0..len / 3];

    var tga = try TGA.from(allocator, path);
    defer tga.deinit();

    try expect(width == tga.width);
    try expect(height == tga.height);
    try expect(len == tga.bytes.len);
    for (expected, 0..) |byte, idx| {
        try expect(byte == tga.bytes[idx * 3]);
        try expect(byte == tga.bytes[idx * 3 + 1]);
        try expect(byte == tga.bytes[idx * 3 + 2]);
    }
}

test "tga: tests/tga/barb.tga" { try testTGAGrayscale("tests/tga/barb.tga"); }
test "tga: tests/tga/bird.tga" { try testTGAGrayscale("tests/tga/bird.tga"); }
test "tga: tests/tga/boat.tga" { try testTGAGrayscale("tests/tga/boat.tga"); }
test "tga: tests/tga/bridge.tga" { try testTGAGrayscale("tests/tga/bridge.tga"); }
test "tga: tests/tga/camera.tga" { try testTGAGrayscale("tests/tga/camera.tga"); }
test "tga: tests/tga/circles.tga" { try testTGAGrayscale("tests/tga/circles.tga"); }
test "tga: tests/tga/clegg.tga" {
    var width: c_int = 0;
    var height: c_int = 0;
    var nr_channels: c_int = 0;

    c.stbi_set_flip_vertically_on_load(1);
    const img = c.stbi_load("tests/tga/clegg.tga", &width, &height, &nr_channels, 1);
    defer c.stbi_image_free(img);

    var tga = try TGA.from(allocator, "tests/tga/clegg.tga");
    defer tga.deinit();

    try expect(width == tga.width);
    try expect(height == tga.height);

    const len: usize = 3 * tga.width * tga.height;
    const expected = img[0..len];

    std.debug.print("{any}\n", .{expected});
}
test "tga: tests/tga/crosses.tga" { try testTGAGrayscale("tests/tga/crosses.tga"); }
test "tga: tests/tga/france.tga" { try testTGAGrayscale("tests/tga/france.tga"); }
test "tga: tests/tga/frog.tga" { try testTGAGrayscale("tests/tga/frog.tga"); }
test "tga: tests/tga/goldhill1.tga" { try testTGAGrayscale("tests/tga/goldhill1.tga"); }
test "tga: tests/tga/goldhill2.tga" { try testTGAGrayscale("tests/tga/goldhill2.tga"); }
test "tga: tests/tga/horiz.tga" { try testTGAGrayscale("tests/tga/horiz.tga"); }
test "tga: tests/tga/lena1.tga" { try testTGAGrayscale("tests/tga/lena1.tga"); }
test "tga: tests/tga/lena2.tga" { try testTGAGrayscale("tests/tga/lena2.tga"); }
test "tga: tests/tga/library.tga" { try testTGAGrayscale("tests/tga/library.tga"); }
test "tga: tests/tga/mandrill.tga" { try testTGAGrayscale("tests/tga/mandrill.tga"); }
test "tga: tests/tga/montage.tga" { try testTGAGrayscale("tests/tga/montage.tga"); }
test "tga: tests/tga/mountain.tga" { try testTGAGrayscale("tests/tga/mountain.tga"); }
test "tga: tests/tga/slope.tga" { try testTGAGrayscale("tests/tga/slope.tga"); }
test "tga: tests/tga/squares.tga" { try testTGAGrayscale("tests/tga/squares.tga"); }
test "tga: tests/tga/text.tga" { try testTGAGrayscale("tests/tga/text.tga"); }
test "tga: tests/tga/washsat.tga" { try testTGAGrayscale("tests/tga/washsat.tga"); }
test "tga: tests/tga/zelda.tga" { try testTGAGrayscale("tests/tga/zelda.tga"); }

// test "tga: https://github.com/ssloy/tinyrenderer/wiki/Lesson-0:-getting-started" {
//     const tga = TGA.init(allocator, 100, 100, .uncompressed_true_color);
//     defer tga.deinit();
//     try tga.set(52, 41, [4]f32{ 255, 255, 255, 255 });
//     try tga.flipVertically();
//     try tga.save("output.tga");
// }
