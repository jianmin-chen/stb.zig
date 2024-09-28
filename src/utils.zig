pub fn sizeof(comptime T: type) usize {
    // Return size in bytes.
    return @bitSizeOf(T) / 8;
}
