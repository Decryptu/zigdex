const std = @import("std");
const sprites = @import("sprites.zig");
const args_module = @import("args.zig");

pub fn main(init: std.process.Init) !void {
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    const args = args_module.parse(argv);

    if (args.help or (!args.random and args.count == 0)) {
        try args_module.printUsage(init.io);
        return;
    }

    if (args.random) {
        try sprites.displayRandom(init.io, args.shiny, args.hide_name);
        return;
    }

    for (args.pokemon_names[0..args.count]) |name| {
        sprites.display(init.io, name, args.shiny, args.hide_name) catch |err| {
            if (err == error.PokemonNotFound) {
                const stderr = std.Io.File.stderr();
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "Pokemon '{s}' not found.\n", .{name});
                try stderr.writeStreamingAll(init.io, msg);
                continue;
            }
            return err;
        };
    }
}

test "CLI parsing and Pokemon lookup" {
    const args = args_module.parse(&.{ "zigdex", "pikachu", "--shiny", "--hide-name" });
    try std.testing.expectEqual(@as(usize, 1), args.count);
    try std.testing.expectEqualStrings("pikachu", args.pokemon_names[0]);
    try std.testing.expect(args.shiny);
    try std.testing.expect(args.hide_name);

    const by_id = sprites.findPokemon("25").?;
    try std.testing.expectEqualStrings("pikachu", by_id.slug);
    try std.testing.expect(by_id == sprites.findPokemon("PIKACHU").?);
    try std.testing.expectEqualStrings("charizard-mega-x", sprites.findPokemon("charizard-mega-x").?.slug);
    try std.testing.expect(sprites.findPokemon("definitely-not-a-pokemon") == null);
}
