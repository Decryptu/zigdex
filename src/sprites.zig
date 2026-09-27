const std = @import("std");
const embedded = @import("embedded_sprites");

pub const Pokemon = embedded.Pokemon;

pub fn findPokemon(query: []const u8) ?*const Pokemon {
    if (std.fmt.parseUnsigned(u16, query, 10)) |n| {
        if (n == 0 or n > embedded.pokemon_count) return null;
        return &embedded.pokemon[n - 1];
    } else |_| {}

    var buf: [64]u8 = undefined;
    if (query.len > buf.len) return null;
    const key = std.ascii.lowerString(&buf, query);
    const i = std.sort.binarySearch(embedded.Key, &embedded.keys, key, struct {
        fn order(k: []const u8, item: embedded.Key) std.math.Order {
            return std.mem.order(u8, k, item.key);
        }
    }.order) orelse return null;
    return &embedded.pokemon[embedded.keys[i].index];
}

pub fn randomPokemon(seed: u64) struct { *const Pokemon, bool } {
    var prng: std.Random.DefaultPrng = .init(seed);
    const random = prng.random();
    const shiny = random.uintLessThan(u8, 128) == 0;
    return .{ &embedded.pokemon[random.uintLessThan(usize, embedded.pokemon_count)], shiny };
}

pub fn write(w: *std.Io.Writer, pokemon: *const Pokemon, shiny: bool, hide_name: bool) !void {
    if (!hide_name) {
        try w.writeAll(pokemon.name);
        try w.writeByte('\n');
    }

    // Without a window buffer, flate inflates straight into `out` and uses it as history.
    var buf: [embedded.max_sprites_len]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buf);
    var in: std.Io.Reader = .fixed(pokemon.sprites);
    var inflate: std.compress.flate.Decompress = .init(&in, .raw, &.{});
    const start: usize = if (shiny) pokemon.regular_len else 0;
    const len: usize = if (shiny) pokemon.shiny_len else pokemon.regular_len;
    try inflate.reader.streamExact(&out, start + len);
    try w.writeAll(buf[start..][0..len]);
}
