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
    try render(w, buf[start..][0..len]);
}

/// Draws an encoded sprite (layout documented in tools/generate_sprites.zig) with half blocks,
/// sending only the SGR changes each cell needs.
fn render(w: *std.Io.Writer, sprite: []const u8) !void {
    const width = sprite[0];
    const height = sprite[1];
    const palette_len = std.mem.readInt(u16, sprite[2..4], .little);
    const palette = sprite[4..][0 .. 3 * @as(usize, palette_len)];
    const cells = sprite[4 + palette.len ..];
    const wide = palette_len > 255;

    // Palette indices, where 0 is the terminal default.
    var fg: u16 = 0;
    var bg: u16 = 0;
    var i: usize = 0;
    for (0..height) |_| {
        for (0..width) |_| {
            const top = pixel(cells, i, wide);
            const bottom = pixel(cells, i + 1, wide);
            i += 2;

            // Opaque tops use ▀ so their color lands in fg; a lone bottom pixel uses ▄.
            // A space only shows its background, so it keeps whatever foreground is active.
            const want_fg = if (top != 0) top else if (bottom != 0) bottom else fg;
            const want_bg = if (top != 0) bottom else 0;

            // Filling a reserved slice directly avoids a writer call per byte.
            const out = try w.writableSliceGreedy("\x1b[38;2;255;255;255;48;2;255;255;255m▀".len);
            var n: usize = 0;
            if (want_fg != fg or want_bg != bg) {
                out[0..2].* = "\x1b[".*;
                n = 2;
                if (want_fg != fg) {
                    n = putColor(out, n, '3', palette, want_fg);
                    fg = want_fg;
                }
                if (want_bg != bg) {
                    if (n > 2) {
                        out[n] = ';';
                        n += 1;
                    }
                    if (want_bg == 0) {
                        out[n..][0..2].* = "49".*;
                        n += 2;
                    } else {
                        n = putColor(out, n, '4', palette, want_bg);
                    }
                    bg = want_bg;
                }
                out[n] = 'm';
                n += 1;
            }
            if (top != 0) {
                out[n..][0..3].* = "▀".*;
                n += 3;
            } else if (bottom != 0) {
                out[n..][0..3].* = "▄".*;
                n += 3;
            } else {
                out[n] = ' ';
                n += 1;
            }
            w.advance(n);
        }
        // Resetting before the newline keeps a set background from bleeding into scrolled lines,
        // and keeps each line self-contained for tools that print sprites beside other text.
        if (fg != 0 or bg != 0) try w.writeAll("\x1b[0m");
        fg = 0;
        bg = 0;
        try w.writeByte('\n');
    }
}

fn pixel(cells: []const u8, i: usize, wide: bool) u16 {
    return if (wide) std.mem.readInt(u16, cells[2 * i ..][0..2], .little) else cells[i];
}

/// Writes `38;2;r;g;b` (or `48;...` for layer '4') at `out[start..]` and returns the new end.
fn putColor(out: []u8, start: usize, layer: u8, palette: []const u8, index: u16) usize {
    out[start..][0..5].* = .{ layer, '8', ';', '2', ';' };
    var n = start + 5;
    for (palette[3 * @as(usize, index - 1) ..][0..3], 0..) |c, channel| {
        if (channel > 0) {
            out[n] = ';';
            n += 1;
        }
        if (c >= 100) {
            out[n] = '0' + c / 100;
            n += 1;
        }
        if (c >= 10) {
            out[n] = '0' + c / 10 % 10;
            n += 1;
        }
        out[n] = '0' + c % 10;
        n += 1;
    }
    return n;
}
