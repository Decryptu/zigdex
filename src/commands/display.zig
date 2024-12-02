const std = @import("std");
const parser = @import("../utils/parser.zig");
const file = @import("../utils/file.zig");

pub fn showPokemon(allocator: std.mem.Allocator, name: []const u8) !void {
    const pokemon = try parser.findPokemonByName(allocator, name) orelse {
        std.debug.print("Pokemon '{}' not found\n", .{name});
        return;
    };

    // Try to read the regular sprite first
    const sprite_path = try std.fmt.allocPrint(
        allocator,
        "assets/colorscripts/regular/{s}",
        .{pokemon.slug},
    );
    defer allocator.free(sprite_path);

    const sprite_content = try file.readFile(allocator, sprite_path);
    defer allocator.free(sprite_content);

    // Print the sprite and information
    try std.io.getStdOut().writeAll(sprite_content);
    try std.io.getStdOut().writeAll("\n");

    // Print Pokemon information
    try std.io.getStdOut().writer().print("\nNo. {d: >3} - {s}\n", .{ pokemon.idx, pokemon.name.en });
    try std.io.getStdOut().writer().print("{s}\n", .{pokemon.desc.en});
}
