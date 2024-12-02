const std = @import("std");
const parser = @import("../utils/parser.zig");
const file = @import("../utils/file.zig");

const DisplayOptions = struct {
    force_shiny: bool = false,
};

pub fn showPokemon(allocator: std.mem.Allocator, name: []const u8, options: DisplayOptions) !void {
    const pokemon = try parser.findPokemonByName(allocator, name) orelse {
        std.debug.print("Pokemon '{s}' not found\n", .{name});
        return;
    };

    // Determine if we should show shiny sprite
    const use_shiny = options.force_shiny;
    const sprite_dir = if (use_shiny) "assets/colorscripts/shiny" else "assets/colorscripts/regular";

    // Create the sprite path
    const sprite_path = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ sprite_dir, pokemon.slug },
    );
    defer allocator.free(sprite_path);

    const sprite_content = try file.readFile(allocator, sprite_path);
    defer allocator.free(sprite_content);

    // Print the sprite and information
    try std.io.getStdOut().writeAll(sprite_content);
    try std.io.getStdOut().writeAll("\n");

    // Print Pokemon information
    const shiny_indicator = if (use_shiny) " ✨" else "";
    try std.io.getStdOut().writer().print("\nNo. {d: >3} - {s}{s}\n", .{
        pokemon.idx,
        pokemon.name.en,
        shiny_indicator,
    });
    try std.io.getStdOut().writer().print("{s}\n", .{pokemon.desc.en});
}

pub fn isShinyFlag(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--shiny") or std.mem.eql(u8, arg, "-s");
}
