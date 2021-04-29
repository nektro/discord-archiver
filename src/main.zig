const std = @import("std");
const ansi = @import("ansi");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &gpa.allocator;

    const proc_args = try std.process.argsAlloc(alloc);
    const args = proc_args[1..];

    if (args.len == 0) {
        std.debug.print(ansi.style.FgRed, .{});
        defer std.debug.print(ansi.style.ResetFgColor, .{});

        std.log.info("must use a command", .{});
        std.log.info("the available commands are:", .{});
        std.log.info("\tchannel BOT_TOKEN CHANNEL_ID", .{});
        return;
    }

    inline for (std.meta.declarations(commands)) |decl| {
        if (std.mem.eql(u8, args[0], decl.name)) {
            const cmd = @field(commands, decl.name);
            try cmd.execute(alloc, args[1..]);
            return;
        }
    }
}

pub const commands = struct {
    pub const channel = @import("./channel.zig");
};
