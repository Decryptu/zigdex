const std = @import("std");

pub const Args = struct {
    help: bool = false,
    random: bool = false,
    shiny: bool = false,
    pokemon_name: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Args) void {
        _ = self;
        // Nothing to deinit in this simple implementation
    }
};

pub fn parse(allocator: std.mem.Allocator) !Args {
    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();

    // Skip executable name
    _ = args_it.skip();

    var result = Args{
        .allocator = allocator,
    };

    var pokemon_specified = false;

    while (args_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            result.help = true;
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--random")) {
            result.random = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--shiny")) {
            result.shiny = true;
        } else if (!pokemon_specified) {
            result.pokemon_name = arg;
            pokemon_specified = true;
        }
    }

    return result;
}

pub fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zigdex [options] [pokemon]
        \\
        \\Options:
        \\  -r, --random    Display a random pokemon
        \\  -s, --shiny     Show shiny variant
        \\  -h, --help      Show this help
        \\
        \\Examples:
        \\  zigdex pikachu
        \\  zigdex pikachu --shiny
        \\  zigdex --random
        \\
    );
}
