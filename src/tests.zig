const c = @cImport({
    @cInclude("stb_image.h");
});
const std = @import("std");

const TGA = @import("tga.zig");

const Allocator = std.mem.Allocator;
const allocator = std.testing.allocator;
const expect = std.testing.expect;

test "tga: tests/tga/barb.tga" {
    var width: c_int = 0;
    var height: c_int = 0;
    var nr_channels: c_int = 0;
    c.stbi_set_flip_vertically_on_load(1);
    const img = c.stbi_load("tests/tga/barb.tga", &width, &height, &nr_channels, 0);
    defer c.stbi_image_free(data);

    const len: usize = 3 * @as(usize, @intCast(width)) * @as(usize, @intCast(height));
    const expected = @ptrCast(img)[0..len];

    const tga = try TGA.from(allocator, "tests/tga/barb.tga");
    defer tga.deinit();

    expect(width == tga.width);
    expect(height == tga.height);
    expect(len == tga.bytes.len);
    expect(std.mem.eql(u8, expected, tga.bytes[0..len]));
}

test "https://github.com/ssloy/tinyrenderer/wiki/Lesson-0:-getting-started" {
    const tga = TGA.init(allocator, 100, 100, .uncompressed_true_color);
    defer tga.deinit();
    try tga.set(52, 41, [4]f32{ 255, 255, 255, 255 });
    try tga.flipVertically();
    try tga.save("output.tga");
}
