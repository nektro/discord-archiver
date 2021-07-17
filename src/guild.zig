const std = @import("std");
const zfetch = @import("zfetch");
const json = @import("json");

const discord = @import("./discord.zig");
const channel = @import("./channel.zig");

pub fn execute(alloc: *std.mem.Allocator, args: [][]u8) !void {
    const bot_token = args[0];
    const guild_id = args[1];

    const guild = try discord.get_guild(alloc, bot_token, guild_id);
    if (guild.?.get("message")) |_| {
        std.log.warn("{}", .{guild});
        return;
    }
    const name = guild.?.get("name").?.String;
    std.log.info("now backing up guild: {s} {s}", .{ guild_id, name });

    if (try discord.get_guild_channels(alloc, bot_token, guild_id)) |response| {
        for (response) |chan| {
            const channel_id = chan.get("id").?.String;
            const ctype = chan.get("type").?.Number;
            if (ctype != 0) {
                continue;
            }
            try channel.do(alloc, bot_token, channel_id);
        }
    }
}
