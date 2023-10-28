const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.target.os.tag;

pub fn writer(comptime Address: type, inner_writer: anytype, pretty: bool) Writer(Address, @TypeOf(inner_writer)) {
    return Writer(Address, @TypeOf(inner_writer)).init(inner_writer, pretty);
}

// Note segmented modes are not supported at this time.
pub fn Writer(comptime Address: type, comptime InnerWriter: type) type {
    switch (@typeInfo(Address).Int.bits) {
        16, 32 => {},
        else => @compileError("Invalid address type; must be u32 or u16"),
    }

    return struct {
        inner: InnerWriter,
        pretty: bool,
        last_address_ext: ?u16 = null,

        const Self = @This();

        pub fn init(inner_writer: InnerWriter, pretty: bool) Self {
            return .{
                .inner = inner_writer,
                .pretty = pretty,
            };
        }

        fn writeByte(self: *Self, d: u8) !void {
            try self.inner.writeByte("0123456789ABCDEF"[d >> 4]);
            try self.inner.writeByte("0123456789ABCDEF"[@as(u4, @truncate(d))]);
        }

        const RecordType = enum (u8) {
            data = 0,
            end_of_file = 1,
            extended_address = 4,
            start_address = 5,
        };

        fn writeRecord(self: *Self, record_type: RecordType, address: u16, data: []const u8) !void {
            try self.inner.writeByte(':');

            var checksum: u8 = 0;

            const length: u8 = @intCast(data.len);
            try self.writeByte(length);
            checksum +%= length;

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            const address_high: u8 = @truncate(address >> 8);
            try self.writeByte(address_high);
            checksum +%= address_high;

            const address_low: u8 = @truncate(address);
            try self.writeByte(address_low);
            checksum +%= address_low;

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            const record_type_byte = @intFromEnum(record_type);
            try self.writeByte(record_type_byte);
            checksum +%= record_type_byte;

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            for (data) |d| {
                try self.writeByte(d);
                checksum +%= d;
            }

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            const signed_checksum: i8 = @bitCast(checksum);
            try self.writeByte(@bitCast(-signed_checksum));

            if (native_os == .windows) {
                try self.inner.writeByte('\r');
            }
            try self.inner.writeByte('\n');
        }

        pub fn write(self: *Self, address: Address, data: []const u8) !void {
            var start = address;
            var remaining = data;

            while (true) {
                var bytes: Address = @intCast(@min(remaining.len, 32));
                if (@bitSizeOf(Address) > 16) {
                    const start_ext: u16 = @truncate(start >> 16);
                    const end_ext: u16 = @truncate((address + bytes) >> 16);
                    if (start_ext != end_ext) {
                        const end = (address + bytes) & 0xFFFF0000;
                        bytes = end - address;
                    }

                    if (start_ext != self.last_address_ext) {
                        const start_ext_be = std.mem.nativeToBig(Address, start_ext);
                        try self.writeRecord(.extended_address, 0, std.mem.asBytes(&start_ext_be));
                        self.last_address_ext = start_ext;
                    }
                }

                try self.writeRecord(.data, @truncate(start), remaining[0..bytes]);
                start += bytes;
                remaining = remaining[bytes..];

                if (remaining.len == 0) break;
            }
        }

        pub fn finish(self: *Self, start_address: ?Address) !void {
            if (start_address) |address| {
                var address_be = std.mem.nativeToBig(Address, address);
                try self.writeRecord(.start_address, 0, std.mem.asBytes(&address_be));
            }

            try self.writeRecord(.end_of_file, 0, "");
        }
    };
}
