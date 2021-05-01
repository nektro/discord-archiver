const std = @import("std");

const zfetch = @import("zfetch");
const json = @import("json");

pub const API_ROOT = "https://discord.com/api";

//
fn do_discord_request(alloc: *std.mem.Allocator, method: zfetch.Method, url: []const u8, bot_token: []const u8) !json.Value {
    const req = try zfetch.Request.init(alloc, url, null);
    defer req.deinit();

    var headers = zfetch.Headers.init(alloc);
    defer headers.deinit();
    try headers.appendValue("Authorization", try std.mem.join(alloc, " ", &.{ "Bot", bot_token }));

    try req.do(.GET, headers, null);
    const r = req.reader();

    const body_content = try r.readAllAlloc(alloc, std.math.maxInt(usize));
    const val = json.parse(alloc, body_content) catch |e| {
        std.log.alert("caught error: {}, dumping response content", .{e});
        std.log.alert("{s}", .{body_content});
        return json.Value{ .Null = void{} };
    };
    return val;
}
//

// https://discord.com/developers/docs/resources/guild#get-guild
pub fn get_guild(alloc: *std.mem.Allocator, bot_token: []const u8, guild_id: []const u8) !?json.Value {
    const url = try std.mem.join(alloc, "/", &.{ API_ROOT, "guilds", guild_id });
    const val = try do_discord_request(alloc, .GET, url, bot_token);
    return val;
}

// https://discord.com/developers/docs/resources/guild#get-guild-channels
// GET/guilds/{guild.id}/channels
pub fn get_guild_channels(alloc: *std.mem.Allocator, bot_token: []const u8, guild_id: []const u8) !?[]json.Value {
    const url = try std.mem.join(alloc, "/", &.{ API_ROOT, "guilds", guild_id, "channels" });
    const val = try do_discord_request(alloc, .GET, url, bot_token);
    if (val != .Array) {
        std.log.err("got non array type from discord", .{});
        std.log.err("{}", .{val});
        return null;
    }
    return val.Array;
}

// https://discord.com/developers/docs/resources/channel#get-channel
pub fn get_channel(alloc: *std.mem.Allocator, bot_token: []const u8, channel_id: []const u8) !?json.Value {
    const url = try std.mem.join(alloc, "/", &.{ API_ROOT, "channels", channel_id });
    const val = try do_discord_request(alloc, .GET, url, bot_token);
    return val;
}

// https://discord.com/developers/docs/resources/channel#get-channel-messages
pub fn get_channel_messages(alloc: *std.mem.Allocator, bot_token: []const u8, channel_id: []const u8, direction: enum { before, after }, flake: []const u8) !?[]json.Value {
    var url = try std.mem.join(alloc, "/", &.{ API_ROOT, "channels", channel_id, "messages" });
    if (flake.len > 0) {
        url = try std.mem.join(alloc, "", &.{ url, "?", std.meta.tagName(direction), "=", flake });
    }
    const val = try do_discord_request(alloc, .GET, url, bot_token);
    if (val != .Array) {
        std.log.err("got non array type from discord", .{});
        std.log.err("{}", .{val});
        return null;
    }
    return val.Array;
}
