//! Small MSB-first bit reader for camera RAW entropy streams.

const std = @import("std");

pub const BitReader = struct {
    data: []const u8,
    bit_position: usize = 0,

    pub fn init(data: []const u8) BitReader {
        return .{ .data = data };
    }

    /// Read up to 32 bits MSB-first, leaving position unchanged on EOF.
    pub fn readBits(self: *BitReader, count: u6) ?u32 {
        if (count == 0) return 0;
        if (count > 32) return null;
        if (self.remainingBits() < count) return null;

        var result: u32 = 0;
        var remaining: u8 = count;
        while (remaining > 0) {
            const byte_index = self.bit_position / 8;
            const bit_in_byte: u3 = @intCast(self.bit_position % 8);
            const available: u8 = 8 - @as(u8, bit_in_byte);
            const take: u8 = @min(available, remaining);
            const shift: u3 = @intCast(available - take);
            const mask: u8 = @intCast((@as(u16, 1) << @intCast(take)) - 1);
            const bits = (self.data[byte_index] >> shift) & mask;

            result = (result << @intCast(take)) | bits;
            self.bit_position += take;
            remaining -= take;
        }
        return result;
    }

    pub fn peekBits(self: *BitReader, count: u6) ?u32 {
        const saved_position = self.bit_position;
        const result = self.readBits(count);
        self.bit_position = saved_position;
        return result;
    }

    /// Peek with zero padding for fixed-width lookup tables near stream end.
    /// Returns null when no source bit remains; padding never advances position.
    pub fn peekBitsPadded(self: *BitReader, count: u6) ?u32 {
        if (count == 0) return 0;
        if (count > 32) return null;

        const available: u6 = @intCast(@min(self.remainingBits(), count));
        if (available == 0) return null;

        const saved_position = self.bit_position;
        const source_bits = self.readBits(available).?;
        self.bit_position = saved_position;
        const padding: u5 = @intCast(count - available);
        return source_bits << padding;
    }

    pub fn skipBits(self: *BitReader, count: usize) bool {
        if (count > self.remainingBits()) return false;
        self.bit_position += count;
        return true;
    }

    fn remainingBits(self: *const BitReader) usize {
        const total_bits = std.math.mul(usize, self.data.len, 8) catch return 0;
        return total_bits -| self.bit_position;
    }
};

test "reads, peeks, and skips across byte boundaries" {
    var reader = BitReader.init(&.{ 0b10110010, 0b01101100 });

    try std.testing.expectEqual(@as(?u32, 0b101), reader.peekBits(3));
    try std.testing.expectEqual(@as(?u32, 0b10110), reader.readBits(5));
    try std.testing.expect(reader.skipBits(2));
    try std.testing.expectEqual(@as(?u32, 0b00110), reader.readBits(5));
    try std.testing.expect(!reader.skipBits(5));
}

test "failed reads do not consume input" {
    var reader = BitReader.init(&.{0xff});
    try std.testing.expectEqual(@as(?u32, null), reader.readBits(9));
    try std.testing.expectEqual(@as(?u32, null), reader.readBits(33));
    try std.testing.expectEqual(@as(?u32, 0xff), reader.readBits(8));
}

test "padded peeks supply lookup zeros without consuming input" {
    var zero_reader = BitReader.init(&.{0x00});
    try std.testing.expectEqual(@as(?u32, 0x000), zero_reader.peekBitsPadded(12));
    try std.testing.expectEqual(@as(?u32, 0x00), zero_reader.readBits(8));

    var high_reader = BitReader.init(&.{0x80});
    try std.testing.expectEqual(@as(?u32, 0x800), high_reader.peekBitsPadded(12));
    try std.testing.expectEqual(@as(?u32, 0x80), high_reader.readBits(8));
}

test "padded peeks work from partial positions and stop at exhaustion" {
    var reader = BitReader.init(&.{0b10100110});
    try std.testing.expectEqual(@as(?u32, 0b101), reader.readBits(3));
    try std.testing.expectEqual(@as(?u32, 0b00110000), reader.peekBitsPadded(8));
    try std.testing.expectEqual(@as(?u32, 0b00110), reader.readBits(5));
    try std.testing.expectEqual(@as(?u32, null), reader.peekBitsPadded(1));
    try std.testing.expectEqual(@as(?u32, 0), reader.peekBitsPadded(0));
}

test "reads the 32-bit limit and skips exactly to the end" {
    var reader = BitReader.init(&.{ 0x12, 0x34, 0x56, 0x78 });
    try std.testing.expectEqual(@as(?u32, 0x12345678), reader.readBits(32));

    var skip_reader = BitReader.init(&.{0xff});
    try std.testing.expect(skip_reader.skipBits(8));
    try std.testing.expectEqual(@as(?u32, null), skip_reader.readBits(1));
}
