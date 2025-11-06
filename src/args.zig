const std = @import("std");

pub const Args = struct {
    help: bool = false,
    random: bool = false,
    shiny: bool = false,
    hide_name: bool = false,
    pokemon_names: [16][]const u8 = undefined,
    count: usize = 0,
};

pub fn parse() Args {
    const args = std.os.argv;

    var result = Args{};

    // Fast path: no arguments
    if (args.len == 1) {
        return result;
    }

    // Parse without any allocations
    for (args[1..]) |arg_ptr| {
        const arg = std.mem.span(arg_ptr);

        // Check for flags and special keywords
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            result.help = true;
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--random") or std.mem.eql(u8, arg, "random")) {
            result.random = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--shiny")) {
            result.shiny = true;
        } else if (std.mem.eql(u8, arg, "--hide-name")) {
            result.hide_name = true;
        } else if (result.count < result.pokemon_names.len) {
            // Everything else is a Pokemon name
            result.pokemon_names[result.count] = arg;
            result.count += 1;
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
        \\  -r, --random, random    Display a random pokemon (1/128 chance for shiny)
        \\  -s, --shiny             Show shiny variant
        \\  --hide-name             Don't print the Pokemon's name
        \\  -h, --help              Show this help
        \\
        \\Examples:
        \\  zigdex pikachu
        \\  zigdex pikachu --shiny --hide-name
        \\  zigdex bulbasaur charmander squirtle
        \\  zigdex random
        \\  zigdex --random
        \\  zigdex 1 25 150
        \\
    );
}
