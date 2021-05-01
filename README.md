# discord-archiver
![loc](https://sloc.xyz/github/nektro/discord-archiver)
[![license](https://img.shields.io/github/license/nektro/discord-archiver.svg)](https://github.com/nektro/discord-archiver/blob/master/LICENSE)
[![discord](https://img.shields.io/discord/551971034593755159.svg?logo=discord)](https://discord.gg/P6Y4zQC)
<!-- [![circleci](https://circleci.com/gh/nektro/discord-archiver.svg?style=svg)](https://circleci.com/gh/nektro/discord-archiver) -->
<!-- [![release](https://img.shields.io/github/v/release/nektro/discord-archiver)](https://github.com/nektro/discord-archiver/releases/latest) -->
<!-- [![downloads](https://img.shields.io/github/downloads/nektro/discord-archiver/total.svg)](https://github.com/nektro/discord-archiver/releases) -->

An archiver for Discord. Written in Zig.

## Usage
1. Channels
```
$ ./discord-archiver channel <BOT_TOKEN> <CHANNEL_ID>
```

2. Guilds
```
$ ./discord-archiver guild <BOT_TOKEN> <GUILD_ID>
```

## Zig
- https://ziglang.org/
- https://github.com/ziglang/zig
- https://github.com/ziglang/zig/wiki/Community

## Building
```
$ zigmod fetch
$ zig build
```

## Built With
- Zig Master & [Zigmod Package Manager](https://github.com/nektro/zigmod)
- https://github.com/nektro/zig-ansi
- https://github.com/truemedian/zfetch

## License
AGPL-3.0
