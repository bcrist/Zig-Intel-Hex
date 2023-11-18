test "pretty=false" {
    const binary = "abcdef123\x00\x10\x01asdf\r\n0\x00";

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);

    var writer = ihex.writer(u32, stream.writer(), .{
        .line_ending = "\n"
    });

    try writer.write(0x1234567, binary);
    try writer.finish(0xABCD);

    try std.testing.expectEqualStrings(
        \\:0400000400000123D4
        \\:14456700616263646566313233001001617364660D0A30005F
        \\:040000050000ABCD7F
        \\:00000001FF
        \\
        , stream.getWritten());
}

test "pretty=true" {
    const binary = "abcdef123\x00\x10\x01asdf\r\n0\x00";

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);

    var writer = ihex.writer(u32, stream.writer(), .{
        .line_ending = "\n",
        .pretty = true,
    });

    try writer.write(0x1234567, binary);
    try writer.finish(0xABCD);

    try std.testing.expectEqualStrings(
        \\:04 0000 04 00000123 D4
        \\:14 4567 00 616263646566313233001001617364660D0A3000 5F
        \\:04 0000 05 0000ABCD 7F
        \\:00 0000 01  FF
        \\
        , stream.getWritten());
}

const ihex = @import("ihex");
const std = @import("std");
