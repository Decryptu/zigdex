const std = @import("std");
const embedded = @import("embedded_sprites");

pub fn findPokemon(name: []const u8) ?*const embedded.Pokemon {
    // Try by slug
    for (&embedded.pokemon_list) |*pokemon| {
        if (std.ascii.eqlIgnoreCase(pokemon.slug, name)) {
            return pokemon;
        }
    }

    // Try by name
    for (&embedded.pokemon_list) |*pokemon| {
        if (std.ascii.eqlIgnoreCase(pokemon.name, name)) {
            return pokemon;
        }
    }

    // Try by ID
    if (std.fmt.parseInt(u16, name, 10)) |idx| {
        for (&embedded.pokemon_list) |*pokemon| {
            if (pokemon.idx == idx) {
                return pokemon;
            }
        }
    } else |_| {}

    return null;
}

pub fn getSprite(pokemon: *const embedded.Pokemon, shiny: bool) []const u8 {
    return if (shiny) pokemon.shiny_sprite else pokemon.regular_sprite;
}

pub fn displayRandom(allocator: std.mem.Allocator, force_shiny: bool, hide_name: bool) !void {
    _ = allocator;

    var prng = std.Random.DefaultPrng.init(@as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))));
    const random = prng.random();

    // 1/128 chance for shiny if not forced
    const is_shiny = force_shiny or (random.intRangeAtMost(u8, 1, 128) == 1);

    const index = random.intRangeAtMost(usize, 0, embedded.pokemon_count - 1);
    const pokemon = &embedded.pokemon_list[index];

    try displayPokemon(pokemon, is_shiny, hide_name);
}

pub fn display(name: []const u8, shiny: bool, hide_name: bool) !void {
    const pokemon = findPokemon(name) orelse return error.PokemonNotFound;
    try displayPokemon(pokemon, shiny, hide_name);
}

fn displayPokemon(pokemon: *const embedded.Pokemon, shiny: bool, hide_name: bool) !void {
    const stdout = std.fs.File.stdout();

    if (!hide_name) {
        var buf: [256]u8 = undefined;
        const name_line = try std.fmt.bufPrint(&buf, "{s}\n", .{pokemon.name});
        try stdout.writeAll(name_line);
    }

    const sprite = getSprite(pokemon, shiny);
    try stdout.writeAll(sprite);
}
