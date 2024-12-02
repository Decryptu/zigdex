const std = @import("std");
const display = @import("display.zig");
const parser = @import("../utils/parser.zig");

var prng = std.rand.DefaultPrng.init(0xdeadbeef);

pub fn displayRandomPokemon(allocator: std.mem.Allocator, force_shiny: bool) !void {
    var rand = prng.random();
    const pokemon_list = try parser.loadPokemonList(allocator);
    defer pokemon_list.deinit(); // Now works with const

    const random_index = rand.intRangeAtMost(usize, 0, pokemon_list.pokemons.len - 1);
    const pokemon = pokemon_list.pokemons[random_index];

    // 1% chance for shiny if not forced
    const random_shiny = if (!force_shiny)
        rand.intRangeAtMost(u8, 0, 99) == 0
    else
        force_shiny;

    try display.showPokemon(allocator, pokemon.slug, .{ .force_shiny = random_shiny });
}
