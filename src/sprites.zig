const std = @import("std");
const embedded = @import("embedded_sprites");

const Xorshift64 = struct {
    state: u64,

    fn init(seed: u64) Xorshift64 {
        return .{ .state = if (seed == 0) 0x123456789abcdef0 else seed };
    }

    fn next(self: *Xorshift64) u64 {
        var x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        return x;
    }

    fn range(self: *Xorshift64, max: usize) usize {
        return @as(usize, @intCast(self.next() % max));
    }
};

pub fn findPokemon(name: []const u8) ?*const embedded.Pokemon {
    // Try parsing as ID first (fastest check)
    if (std.fmt.parseInt(u16, name, 10)) |idx| {
        for (&embedded.pokemon_list) |*pokemon| {
            if (pokemon.idx == idx) return pokemon;
        }
    } else |_| {}

    // Linear search by slug
    for (&embedded.pokemon_list) |*pokemon| {
        if (std.ascii.eqlIgnoreCase(pokemon.slug, name)) return pokemon;
    }

    // Linear search by name
    for (&embedded.pokemon_list) |*pokemon| {
        if (std.ascii.eqlIgnoreCase(pokemon.name, name)) return pokemon;
    }

    return null;
}

inline fn getSprite(pokemon: *const embedded.Pokemon, shiny: bool) []const u8 {
    return if (shiny) pokemon.shiny_sprite else pokemon.regular_sprite;
}

pub fn displayRandom(force_shiny: bool, hide_name: bool) !void {
    const seed = @as(u64, @bitCast(@as(i64, @truncate(std.time.nanoTimestamp()))));
    var rng = Xorshift64.init(seed);

    const is_shiny = force_shiny or (rng.next() % 128 == 0);
    const index = rng.range(embedded.pokemon_count);
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

    try stdout.writeAll(getSprite(pokemon, shiny));
}
