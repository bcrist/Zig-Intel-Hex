pub fn writer(comptime Address: type, w: *std.io.Writer, options: Writer_Options) Writer(Address) {
    return Writer(Address).init(w, options);
}

pub const Writer_Options = struct {
    line_ending: ?[]const u8 = null,
    pretty: bool = false,
};

// Note segmented modes are not supported at this time.
pub fn Writer(comptime Address: type) type {
    switch (@typeInfo(Address).int.bits) {
        16, 32 => {},
        else => @compileError("Invalid address type; must be u32 or u16"),
    }

    return struct {
        inner: *std.io.Writer,
        pretty: bool,
        line_ending: []const u8,
        last_address_ext: ?u16 = null,

        const Self = @This();

        pub fn init(w: *std.io.Writer, options: Writer_Options) Self {
            return .{
                .inner = w,
                .line_ending = options.line_ending orelse default_line_ending(),
                .pretty = options.pretty,
            };
        }

        fn write_byte(self: *Self, d: u8) !void {
            try self.inner.writeByte("0123456789ABCDEF"[d >> 4]);
            try self.inner.writeByte("0123456789ABCDEF"[@as(u4, @truncate(d))]);
        }

        const Record_Type = enum (u8) {
            data = 0,
            end_of_file = 1,
            extended_address = 4,
            start_address = 5,
        };

        fn write_record(self: *Self, record_type: Record_Type, address: u16, data: []const u8) !void {
            try self.inner.writeByte(':');

            var checksum: u8 = 0;

            const length: u8 = @intCast(data.len);
            try self.write_byte(length);
            checksum +%= length;

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            const address_high: u8 = @truncate(address >> 8);
            try self.write_byte(address_high);
            checksum +%= address_high;

            const address_low: u8 = @truncate(address);
            try self.write_byte(address_low);
            checksum +%= address_low;

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            const record_type_byte = @intFromEnum(record_type);
            try self.write_byte(record_type_byte);
            checksum +%= record_type_byte;

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            for (data) |d| {
                try self.write_byte(d);
                checksum +%= d;
            }

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            const signed_checksum: i8 = @bitCast(checksum);
            try self.write_byte(@bitCast(-%signed_checksum));

            try self.inner.writeAll(self.line_ending);
        }

        pub fn write(self: *Self, address: Address, data: []const u8) !void {
            var start = address;
            var remaining = data;

            while (true) {
                var bytes: Address = @intCast(@min(remaining.len, 32));
                if (@bitSizeOf(Address) > 16) {
                    const start_ext: u16 = @truncate(start >> 16);
                    const end_ext: u16 = @truncate((start + bytes) >> 16);
                    if (start_ext != end_ext) {
                        const end = (start + bytes) & 0xFFFF0000;
                        bytes = end - start;
                    }

                    if (start_ext != self.last_address_ext) {
                        const start_ext_be = std.mem.nativeToBig(Address, start_ext);
                        try self.write_record(.extended_address, 0, std.mem.asBytes(&start_ext_be));
                        self.last_address_ext = start_ext;
                    }
                }

                try self.write_record(.data, @truncate(start), remaining[0..bytes]);
                start += bytes;
                remaining = remaining[bytes..];

                if (remaining.len == 0) break;
            }
        }

        pub fn finish(self: *Self, start_address: ?Address) !void {
            if (start_address) |address| {
                var address_be = std.mem.nativeToBig(Address, address);
                try self.write_record(.start_address, 0, std.mem.asBytes(&address_be));
            }

            try self.write_record(.end_of_file, 0, "");
        }
    };
}

fn default_line_ending() []const u8 {
    return if (@import("builtin").target.os.tag == .windows) "\r\n" else "\n";
}

const std = @import("std");
