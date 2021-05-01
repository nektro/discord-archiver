const std = @import("std");
const zfetch = @import("zfetch");

const discord = @import("./discord.zig");
const json = @import("json");

const Direction = enum {
    before,
    after,
};

pub fn execute(alloc: *std.mem.Allocator, args: [][]u8) !void {
    const bot_token = args[0];

    for (range(args.len - 1)) |_, i| {
        try do(alloc, bot_token, args[i + 1]);
    }
}

pub fn do(alloc: *std.mem.Allocator, bot_token: []const u8, channel_id: []const u8) !void {
    const channel = try get_channel(alloc, bot_token, channel_id);
    if (channel.?.get("message")) |msg| {
        std.log.warn("{}", .{channel});
        return;
    }
    const name = channel.?.get("name").?.String;
    std.log.info("now backing up channel: {s} {s}", .{ channel_id, name });

    const save_path = try std.mem.join(alloc, "", &.{ channel_id, "_", name, ".txt" });

    const f = try std.fs.cwd().createFile(save_path, .{ .read = true, .truncate = false });
    defer f.close();
    const r = f.reader();
    const w = f.writer();

    const message_list = &std.ArrayList(json.Value).init(alloc);
    defer message_list.deinit();

    if ((try f.getEndPos()) == 0) {
        // full sync
        var next_flake: []const u8 = "";
        while (try get_messages(alloc, bot_token, channel_id, .before, next_flake)) |messages| {
            if (messages.len == 0) break;
            std.log.info("found {} messages starting at {s}", .{ messages.len, messages[0].get("id").?.String });
            try message_list.appendSlice(messages);
            if (messages.len < 50) break;
            std.time.sleep(std.time.ns_per_s);
            next_flake = messages[messages.len - 1].get("id").?.String;
        }
    } else {
        // only append new messages
        std.log.info("backup has already been done", .{});
        var last_line: []const u8 = "";
        while (try r.readUntilDelimiterOrEofAlloc(alloc, '\n', std.math.maxInt(usize))) |line| {
            last_line = line;
        }
        const val = try json.parse(alloc, last_line);
        const id = val.get("id").?.String;
        std.log.info("last saved id is {s}", .{id});

        try f.seekTo(try f.getEndPos());
        var next_flake = id;
        while (try get_messages(alloc, bot_token, channel_id, .after, next_flake)) |messages| {
            if (messages.len == 0) break;
            std.log.info("found {} messages starting at {s}", .{ messages.len, messages[0].get("id").?.String });
            try message_list.appendSlice(messages);
            if (messages.len < 50) break;
            std.time.sleep(std.time.ns_per_s);
            next_flake = messages[messages.len - 1].get("id").?.String;
        }
    }

    std.log.info("saving {} messages to disk", .{message_list.items.len});
    for (range(message_list.items.len)) |_, i| {
        try w.print("{}\n", .{message_list.items[message_list.items.len - 1 - i]});
    }

    std.log.info("done", .{});
}

fn range(len: usize) []const u0 {
    return @as([*]u0, undefined)[0..len];
}

fn get_channel(alloc: *std.mem.Allocator, bot_token: []const u8, channel_id: []const u8) !?json.Value {
    const url = try std.mem.join(alloc, "", &.{ discord.API_ROOT, "/channels/", channel_id });
    const val = try do_discord_request(alloc, .GET, url, bot_token);
    return val;
}

fn get_messages(alloc: *std.mem.Allocator, bot_token: []const u8, channel_id: []const u8, direction: Direction, flake: []const u8) !?[]json.Value {
    var url = try std.mem.join(alloc, "", &.{
        discord.API_ROOT, "/channels/",
        channel_id,       "/messages",
    });
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
