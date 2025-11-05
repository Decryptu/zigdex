const std = @import("std");

pub const Args = struct {
    help: bool = false,
    random: bool = false,
    shiny: bool = false,
    hide_name: bool = false,
    pokemon_names: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Args) void {
        self.pokemon_names.deinit(self.allocator);
    }
};

pub fn parse(allocator: std.mem.Allocator) !Args {
    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();

    _ = args_it.skip();

    var result = Args{
        .allocator = allocator,
        .pokemon_names = std.ArrayList([]const u8).initCapacity(allocator, 8) catch |err| {
            return err;
        },
    };

    while (args_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            result.help = true;
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--random") or std.mem.eql(u8, arg, "random")) {
            result.random = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--shiny")) {
            result.shiny = true;
        } else if (std.mem.eql(u8, arg, "--hide-name")) {
            result.hide_name = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            try result.pokemon_names.append(allocator, arg);
        }
    }

    return result;
}

pub fn printUsage() !void {
    try std.fs.File.stdout().writeAll(
        \\zigdex - Display Pokemon sprites in your terminal
        \\
        \\Usage: zigdex [options] [pokemon...]
        \\
        \\Options:
        \\  -r, --random    Display a random pokemon (1/128 chance for shiny)
        \\  -s, --shiny     Show shiny variant
        \\  --hide-name     Don't print the Pokemon's name
        \\  -h, --help      Show this help
        \\
        \\Examples:
        \\  zigdex pikachu
        \\  zigdex pikachu --shiny --hide-name
        \\  zigdex bulbasaur charmander squirtle
        \\  zigdex --random
        \\  zigdex 1 25 150
        \\
    );
}
