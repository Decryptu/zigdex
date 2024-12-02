const std = @import("std");
const display = @import("display.zig");
const parser = @import("../utils/parser.zig");

var prng = std.rand.DefaultPrng.init(blk: {
    var seed: u64 = undefined;
    std.os.getrandom(std.mem.asBytes(&seed)) catch |err| {
        std.debug.print("Failed to get random seed: {}\n", .{err});
        break :blk @intCast(std.time.timestamp());
    };
    break :blk seed;
});

pub fn displayRandomPokemon(allocator: std.mem.Allocator) !void {
    const pokemon_list = try parser.loadPokemonList(allocator);
    defer pokemon_list.deinit();

    const random_index = prng.random().intRangeAtMost(usize, 0, pokemon_list.pokemons.len - 1);
    const pokemon = pokemon_list.pokemons[random_index];

    try display.showPokemon(allocator, pokemon.slug);
}
