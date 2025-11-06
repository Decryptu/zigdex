const std = @import("std");
const sprites = @import("sprites.zig");
const args_module = @import("args.zig");

pub fn main() !void {
    const args = args_module.parse();

    if (args.help or (!args.random and args.count == 0)) {
        try args_module.printUsage();
        return;
    }

    if (args.random) {
        try sprites.displayRandom(args.shiny, args.hide_name);
        return;
    }

    for (args.pokemon_names[0..args.count]) |name| {
        sprites.display(name, args.shiny, args.hide_name) catch |err| {
            if (err == error.PokemonNotFound) {
                const stderr = std.fs.File.stderr();
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "Pokemon '{s}' not found.\n", .{name});
                try stderr.writeAll(msg);
                continue;
            }
            return err;
        };
    }
}
