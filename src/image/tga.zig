const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

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

const Self = @This();

allocator: Allocator,

bytes: []u8 = undefined,
width: usize = 0,
height: usize = 0,
kind: ImageKind = .none,

_bytes: ?[]u8 = null,
_header: ?*align(1) Header = null,

pub fn from(allocator: Allocator, path: []const u8) !Self {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var self: Self = .{
        .allocator = allocator,
        ._bytes = try allocator.alloc(u8, try file.getEndPos())
    };

    _ = try file.readAll(self._bytes orelse unreachable);

    const header: *align(1) Header = @ptrCast(self._bytes);
    self._header = header;

    self.width = header.image_width;
    self.height = header.image_height;
    self.kind = @enumFromInt(header.image_type);

    try self.parse();

    return self;
}

pub fn init(allocator: Allocator, width: usize, height: usize, kind: ImageKind) !Self {
    const self: Self = .{
        .allocator = allocator,

        .bytes = try allocator.alloc(u8, 3 * width * height),
        .width = width,
        .height = height,
        .kind = kind
    };
    for (0..3 * width * height) |idx| {
        self.bytes[idx] = 0;
    }
    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.bytes);
    if (self._bytes) |bytes| {
        self.allocator.free(bytes);
    }
}

pub fn save(self: *Self, path: []const u8) !void {
    const output = try std.fs.cwd().createFile(path, .{});
    defer output.close();

    if (self._header == null) {
        var header: Header = .{
            .id_length = 0,
            .colormap_type = 0,
            .image_type = @intFromEnum(self.kind),
            .colormap_first_entry = 0,
            .colormap_length = 0,
            .colormap_entry_size = 0,
            .x_origin = 0,
            .y_origin = 0,
            .image_width = @intCast(self.width),
            .image_height = @intCast(self.height),
            .pixel_depth = 24,
            .image_descriptor = 0
        };
        const bytes: []u8 = std.mem.asBytes(&header);
        _ = try output.write(bytes);
    }

    _ = try output.write(self.bytes);
}

fn parse(self: *Self) !void {
    const _bytes = self._bytes orelse unreachable;
    const _header = self._header orelse unreachable;

    const offset = @bitSizeOf(Header) / 8 + _header.id_length + _header.colormap_type;
    const size: usize = (_header.pixel_depth * self.width * self.height) / 8;
    const img = _bytes[offset..offset + size];

    switch (self.kind) {
        .uncompressed_true_color => {
            std.debug.print("{any}", .{_header});
            switch (_header.pixel_depth) {
                24 => {
                    self.bytes = try self.allocator.alloc(u8, 3 * self.width * self.height);
                    var idx: usize = 0;
                    while (idx < img.len) : (idx += 3) {
                        const bytes = img[idx..idx + 3];
                        self.bytes[idx] = bytes[2];
                        self.bytes[idx + 1] = bytes[1];
                        self.bytes[idx + 2] = bytes[0];
                    }
                },
                else => {}
            }
        },
        .uncompressed_grayscale => {
            self.bytes = try self.allocator.alloc(u8, size * 3);
            for (img, 0..) |byte, idx| {
                self.bytes[idx * 3] = byte;
                self.bytes[idx * 3 + 1] = byte;
                self.bytes[idx * 3 + 2] = byte;
            }
        },
        else => {}
    }
}

// Extra utility functions.
pub fn flipVertically(self: *Self) void {
    const copy = self.bytes;

}

pub fn set(self: *Self, x: usize, y: usize, color: [3]u8) void {
    assert(x < self.width);
    assert(y < self.height);
    const idx = (x + y * self.width);
    self.bytes[idx] = color[0];
    self.bytes[idx + 1] = color[1];
    self.bytes[idx + 2] = color[2];
}

pub fn get(self: *Self, x: usize, y: usize) !u8 {
    _ = x;
    _ = y;
    return self._bytes[0];
}
