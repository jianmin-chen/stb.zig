const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Header = packed struct {
    id_length: u8,
    colormap_type: u8,
    image_type: u8,
    colormap_first_entry: u16,
    colormap_length: u16,
    colormap_entry_size: u8,
    x_origin: u16,
    y_origin: u16,
    image_width: u16,
    image_height: u16,
    pixel_depth: u8,
    image_descriptor: u8,
};

const ImageKind = enum(u8) {
    none = 0,
    uncompressed_colormapped = 1,
    uncompressed_true_color = 2,
    uncompressed_grayscale = 3,
    rle_colormapped = 9,
    rle_true_color = 10,
    rle_grayscale = 11,
    _
};

const ParserError = error{

};

const Self = @This();

allocator: Allocator,
path: []const u8,

bytes: []u8 = undefined,
width: usize = 0,
height: usize = 0,
kind: ImageKind = .none,

_bytes: []u8 = undefined,
_header: *align(1) Header = undefined,

pub fn from(allocator: Allocator, path: []const u8) !Self {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var self: Self = .{
        .allocator = allocator,
        .path = path,
        ._bytes = try allocator.alloc(u8, try file.getEndPos())
    };

    _ = try file.readAll(self._bytes);

    self._header = @ptrCast(self._bytes);

    self.width = self._header.image_width;
    self.height = self._header.image_height;
    self.kind = @enumFromInt(self._header.image_type);

    try self.parse();

    return self;
}

pub fn init(allocator: Allocator, width: usize, height: usize) !Self {
    const self: Self = .{
        .allocator = allocator,
        .path = "",

        .width = width,
        .height = height
    };

    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.bytes);
    self.allocator.free(self._bytes);
}

pub fn save(self: *Self, path: []const u8) void {
    self.path = path;
}

fn parse(self: *Self) !void {
    const offset = utils.sizeof(Header) + self._header.id_length + self._header.colormap_type;
    const size = (
        @as(usize, self._header.pixel_depth) * self.width * self.height
    ) / 8;
    const img = self._bytes[offset..offset + size];

    switch (self.kind) {
        .uncompressed_grayscale => {
            self.bytes = try self.allocator.alloc(u8, size * 3);
            for (img, 0..) |byte, idx| {
                self.bytes[idx] = byte;
                self.bytes[idx + 1] = byte;
                self.bytes[idx + 2] = byte;
            }
        },
        else => {}
    }
}

// Extra utility functions.
pub fn flipVertically(self: *Self) !void {
    _ = self;
}

pub fn get(self: *Self, x: usize, y: usize) !u8 {
    _ = x;
    _ = y;
    return self._bytes[0];
}
