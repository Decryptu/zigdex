const std = @import("std");

const Flag = enum { help, random, shiny, hide_name };

const flags: std.StaticStringMap(Flag) = .initComptime(.{
    .{ "-h", .help },
    .{ "--help", .help },
    .{ "-r", .random },
    .{ "--random", .random },
    .{ "random", .random },
    .{ "-s", .shiny },
    .{ "--shiny", .shiny },
    .{ "--hide-name", .hide_name },
});

pub const Args = struct {
    help: bool = false,
    random: bool = false,
    shiny: bool = false,
    hide_name: bool = false,
    name_count: usize = 0,
};

/// Every argument that is not a flag names a Pokemon.
pub fn isName(arg: []const u8) bool {
    return flags.get(arg) == null;
}

pub fn parse(args: []const [*:0]const u8) Args {
    var result: Args = .{};
    for (args) |ptr| {
        const flag = flags.get(std.mem.span(ptr)) orelse {
            result.name_count += 1;
            continue;
        };
        switch (flag) {
            .help => result.help = true,
            .random => result.random = true,
            .shiny => result.shiny = true,
            .hide_name => result.hide_name = true,
        }
    }
    return result;
}

pub const usage =
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
;
