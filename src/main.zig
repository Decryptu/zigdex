const std = @import("std");
const sprites = @import("sprites.zig");
const args_module = @import("args.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try args_module.parse(allocator);
    defer args.deinit();

    if (args.help or (!args.random and args.pokemon_names.items.len == 0)) {
        try args_module.printUsage();
        return;
    }

    if (args.random) {
        try sprites.displayRandom(allocator, args.shiny, args.hide_name);
        return;
    }

    for (args.pokemon_names.items) |name| {
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
