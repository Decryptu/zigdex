const std = @import("std");

const Rgb = [3]u8;

/// One terminal cell holds two vertical pixels; null is transparent.
const Cell = struct { top: ?Rgb, bottom: ?Rgb };

const Sprite = struct {
    width: usize,
    cells: []Cell,
};

const Entry = struct {
    idx: u16,
    slug: []const u8,
    name: []const u8,
    offset: usize,
    len: usize,
    regular_len: usize,
    shiny_len: usize,
};

const Key = struct {
    key: []const u8,
    index: usize,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);

    if (args.len != 4) {
        std.debug.print("Usage: {s} <pokemon.json> <colorscripts_dir> <output_dir>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const cwd = std.Io.Dir.cwd();
    const json_data = try cwd.readFileAlloc(io, args[1], arena, .limited(16 * 1024 * 1024));
    const sprites_dir = try cwd.openDir(io, args[2], .{});
    const out_dir = try cwd.createDirPathOpen(io, args[3], .{});

    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, json_data, .{});

    var entries: std.ArrayList(Entry) = .empty;
    var blob: std.ArrayList(u8) = .empty;
    var max_len: usize = 0;
    var pokemon_count: usize = 0;

    for (parsed.array.items) |item| {
        const obj = item.object;
        const idx: u16 = @intCast(obj.get("idx").?.integer);
        if (idx != pokemon_count + 1) return error.PokedexNotContiguous;
        const slug = obj.get("slug").?.string;
        const name = obj.get("name").?.object.get("en").?.string;
        try entries.append(arena, try addEntry(arena, io, sprites_dir, &blob, &max_len, idx, slug, name));
        pokemon_count += 1;
    }

    for (parsed.array.items) |item| {
        const obj = item.object;
        const forms = obj.get("forms") orelse continue;
        const idx: u16 = @intCast(obj.get("idx").?.integer);
        const base_slug = obj.get("slug").?.string;
        const base_name = obj.get("name").?.object.get("en").?.string;
        for (forms.array.items) |form| {
            const slug = try std.fmt.allocPrint(arena, "{s}-{s}", .{ base_slug, form.string });
            const name = try formDisplayName(arena, base_name, form.string);
            try entries.append(arena, try addEntry(arena, io, sprites_dir, &blob, &max_len, idx, slug, name));
        }
    }

    // Earlier keys win on collision, preserving lookup precedence: slugs before names, species before forms.
    var keys: std.ArrayList(Key) = .empty;
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    for ([_]bool{ true, false }) |by_slug| {
        for (entries.items, 0..) |entry, i| {
            const key = try std.ascii.allocLowerString(arena, if (by_slug) entry.slug else entry.name);
            if ((try seen.getOrPut(arena, key)).found_existing) continue;
            try keys.append(arena, .{ .key = key, .index = i });
        }
    }
    std.mem.sortUnstable(Key, keys.items, {}, struct {
        fn lessThan(_: void, a: Key, b: Key) bool {
            return std.mem.lessThan(u8, a.key, b.key);
        }
    }.lessThan);

    // Tables hold offsets into the embedded data rather than slices: pointers stored in data
    // must be rebased by the dynamic loader on every launch, which dominates startup on macOS.
    var strings: Strings = .{ .data = &blob };
    var source: std.Io.Writer.Allocating = .init(arena);
    const w = &source.writer;
    try w.print(
        \\/// A byte range of `data`.
        \\pub const Span = struct {{ start: u32, len: u32 }};
        \\
        \\pub const Pokemon = struct {{
        \\    idx: u16,
        \\    slug: Span,
        \\    name: Span,
        \\    /// Raw deflate stream of the encoded regular sprite followed by the shiny one.
        \\    sprites: Span,
        \\    regular_len: u32,
        \\    shiny_len: u32,
        \\}};
        \\
        \\pub const Key = struct {{ key: Span, index: u16 }};
        \\
        \\pub const pokemon_count = {d};
        \\pub const max_sprites_len = {d};
        \\
        \\pub const data = @embedFile("data.bin");
        \\
        \\/// National dex species in order, followed by alternate forms.
        \\pub const pokemon = [_]Pokemon{{
        \\
    , .{ pokemon_count, max_len });
    for (entries.items) |e| {
        try w.print("    .{{ .idx = {d}, .slug = {f}, .name = {f}, .sprites = .{{ .start = {d}, .len = {d} }}, .regular_len = {d}, .shiny_len = {d} }},\n", .{
            e.idx, try strings.intern(arena, e.slug), try strings.intern(arena, e.name), e.offset, e.len, e.regular_len, e.shiny_len,
        });
    }
    try w.writeAll("};\n\n/// Lowercase slugs and names, sorted for binary search.\npub const keys = [_]Key{\n");
    for (keys.items) |k| {
        try w.print("    .{{ .key = {f}, .index = {d} }},\n", .{ try strings.intern(arena, k.key), k.index });
    }
    try w.writeAll("};\n");

    try out_dir.writeFile(io, .{ .sub_path = "data.bin", .data = blob.items });
    try out_dir.writeFile(io, .{ .sub_path = "embedded_sprites.zig", .data = source.written() });
}

/// Appends strings to the embedded data once each, formatting their location as a `Span` literal.
const Strings = struct {
    data: *std.ArrayList(u8),
    seen: std.StringHashMapUnmanaged(Span) = .empty,

    const Span = struct {
        start: usize,
        len: usize,

        pub fn format(span: Span, w: *std.Io.Writer) std.Io.Writer.Error!void {
            try w.print(".{{ .start = {d}, .len = {d} }}", .{ span.start, span.len });
        }
    };

    fn intern(strings: *Strings, arena: std.mem.Allocator, text: []const u8) !Span {
        const entry = try strings.seen.getOrPut(arena, text);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{ .start = strings.data.items.len, .len = text.len };
            try strings.data.appendSlice(arena, text);
        }
        return entry.value_ptr.*;
    }
};

fn addEntry(
    arena: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    blob: *std.ArrayList(u8),
    max_len: *usize,
    idx: u16,
    slug: []const u8,
    name: []const u8,
) !Entry {
    const regular = try loadSprite(arena, io, dir, "regular", slug);
    const shiny = loadSprite(arena, io, dir, "shiny", slug) catch |err| switch (err) {
        error.FileNotFound => regular,
        else => return err,
    };

    var encoded: std.Io.Writer.Allocating = .init(arena);
    try encode(arena, &encoded.writer, regular);
    const regular_len = encoded.written().len;
    try encode(arena, &encoded.writer, shiny);
    const total = encoded.written().len;

    const offset = blob.items.len;
    try deflateRaw(arena, blob, encoded.written()[0..regular_len], encoded.written()[regular_len..]);
    max_len.* = @max(max_len.*, total);

    return .{
        .idx = idx,
        .slug = slug,
        .name = name,
        .offset = offset,
        .len = blob.items.len - offset,
        .regular_len = regular_len,
        .shiny_len = total - regular_len,
    };
}

fn loadSprite(arena: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, variant: []const u8, slug: []const u8) !Sprite {
    const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ variant, slug });
    const text = try dir.readFileAlloc(io, path, arena, .limited(1024 * 1024));
    const sprite = parse(arena, text) catch |err| {
        std.debug.print("{s}: {t}\n", .{ path, err });
        return err;
    };
    return crop(arena, sprite);
}

/// Replays the ANSI text like a terminal would, recording what each cell shows.
fn parse(arena: std.mem.Allocator, text: []const u8) !Sprite {
    var cells: std.ArrayList(Cell) = .empty;
    var width: ?usize = null;
    var row_start: usize = 0;
    var fg: ?Rgb = null;
    var bg: ?Rgb = null;

    var i: usize = 0;
    while (i < text.len) {
        if (std.mem.startsWith(u8, text[i..], "\x1b[")) {
            const end = std.mem.indexOfScalarPos(u8, text, i, 'm') orelse return error.BadEscape;
            try applySgr(text[i + 2 .. end], &fg, &bg);
            i = end + 1;
        } else if (text[i] == '\n') {
            const row_len = cells.items.len - row_start;
            if (row_len != 0) {
                if (width != null and width != row_len) return error.RaggedRows;
                width = row_len;
            }
            row_start = cells.items.len;
            i += 1;
        } else if (text[i] == ' ') {
            try cells.append(arena, .{ .top = bg, .bottom = bg });
            i += 1;
        } else if (std.mem.startsWith(u8, text[i..], "▀")) {
            try cells.append(arena, .{ .top = fg, .bottom = bg });
            i += "▀".len;
        } else if (std.mem.startsWith(u8, text[i..], "▄")) {
            try cells.append(arena, .{ .top = bg, .bottom = fg });
            i += "▄".len;
        } else return error.UnexpectedByte;
    }
    if (cells.items.len != row_start) return error.MissingFinalNewline;
    return .{ .width = width orelse return error.EmptySprite, .cells = cells.items };
}

fn applySgr(params: []const u8, fg: *?Rgb, bg: *?Rgb) !void {
    var values: [16]u8 = undefined;
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, params, ';');
    while (it.next()) |p| : (n += 1) {
        if (n == values.len) return error.BadEscape;
        values[n] = if (p.len == 0) 0 else try std.fmt.parseInt(u8, p, 10);
    }

    var i: usize = 0;
    while (i < n) : (i += 1) switch (values[i]) {
        0 => {
            fg.* = null;
            bg.* = null;
        },
        39 => fg.* = null,
        49 => bg.* = null,
        38, 48 => {
            const target = if (values[i] == 38) fg else bg;
            if (i + 2 < n and values[i + 1] == 5) {
                target.* = xterm256(values[i + 2]);
                i += 2;
            } else if (i + 4 < n and values[i + 1] == 2) {
                target.* = values[i + 2 ..][0..3].*;
                i += 4;
            } else return error.BadEscape;
        },
        else => return error.UnsupportedSgr,
    };
}

/// Resolves 256-color indices with xterm's default palette so every sprite renders in truecolor.
fn xterm256(n: u8) Rgb {
    const system = [16]Rgb{
        .{ 0, 0, 0 },       .{ 205, 0, 0 },   .{ 0, 205, 0 },   .{ 205, 205, 0 },
        .{ 0, 0, 238 },     .{ 205, 0, 205 }, .{ 0, 205, 205 }, .{ 229, 229, 229 },
        .{ 127, 127, 127 }, .{ 255, 0, 0 },   .{ 0, 255, 0 },   .{ 255, 255, 0 },
        .{ 92, 92, 255 },   .{ 255, 0, 255 }, .{ 0, 255, 255 }, .{ 255, 255, 255 },
    };
    if (n < 16) return system[n];
    if (n < 232) {
        const levels = [6]u8{ 0, 95, 135, 175, 215, 255 };
        const i = n - 16;
        return .{ levels[i / 36], levels[i / 6 % 6], levels[i % 6] };
    }
    const gray = 8 + 10 * (n - 232);
    return .{ gray, gray, gray };
}

fn isBlank(cell: Cell) bool {
    return cell.top == null and cell.bottom == null;
}

/// Drops fully transparent border rows and columns.
fn crop(arena: std.mem.Allocator, s: Sprite) !Sprite {
    const height = s.cells.len / s.width;
    var top: usize = height;
    var bottom: usize = 0;
    var left: usize = s.width;
    var right: usize = 0;
    for (0..height) |y| {
        for (0..s.width) |x| {
            if (isBlank(s.cells[y * s.width + x])) continue;
            top = @min(top, y);
            bottom = @max(bottom, y + 1);
            left = @min(left, x);
            right = @max(right, x + 1);
        }
    }
    if (top == height) return error.EmptySprite;
    if (top == 0 and bottom == height and left == 0 and right == s.width) return s;

    const width = right - left;
    const cells = try arena.alloc(Cell, width * (bottom - top));
    for (top..bottom, 0..) |y, row| {
        @memcpy(cells[row * width ..][0..width], s.cells[y * s.width + left ..][0..width]);
    }
    return .{ .width = width, .cells = cells };
}

/// Writes the layout `src/sprites.zig` renders: width, height, a little-endian u16 palette
/// length, the RGB palette, then a top and bottom palette index per cell where 0 is transparent.
/// Indices are u16 when the palette has more than 255 colors.
fn encode(arena: std.mem.Allocator, w: *std.Io.Writer, s: Sprite) !void {
    const height = s.cells.len / s.width;
    if (s.width > 255 or height > 255) return error.SpriteTooLarge;

    var palette: std.AutoArrayHashMapUnmanaged(Rgb, void) = .empty;
    for (s.cells) |cell| {
        if (cell.top) |color| try palette.put(arena, color, {});
        if (cell.bottom) |color| try palette.put(arena, color, {});
    }

    try w.writeByte(@intCast(s.width));
    try w.writeByte(@intCast(height));
    try w.writeInt(u16, @intCast(palette.count()), .little);
    for (palette.keys()) |color| try w.writeAll(&color);

    const wide = palette.count() > 255;
    for (s.cells) |cell| {
        for ([_]?Rgb{ cell.top, cell.bottom }) |pixel| {
            const index: u16 = if (pixel) |color| @intCast(palette.getIndex(color).? + 1) else 0;
            if (wide) try w.writeInt(u16, index, .little) else try w.writeByte(@intCast(index));
        }
    }
}

/// Compresses both sprites as one raw deflate stream so the shiny one can reference the regular one.
fn deflateRaw(arena: std.mem.Allocator, out: *std.ArrayList(u8), regular: []const u8, shiny: []const u8) !void {
    // Compressed output is smaller than its input, and Compress needs a non-empty output buffer.
    try out.ensureUnusedCapacity(arena, regular.len + shiny.len);
    var aw: std.Io.Writer.Allocating = .fromArrayList(arena, out);
    defer out.* = aw.toArrayList();
    var window: [std.compress.flate.max_window_len]u8 = undefined;
    var z: std.compress.flate.Compress = try .init(&aw.writer, &window, .raw, .best);
    try z.writer.writeAll(regular);
    // Inflating straight into the output cannot stop inside a match, so none may cross into the shiny sprite.
    try z.writer.flush();
    try z.writer.writeAll(shiny);
    try z.finish();
}

fn formDisplayName(arena: std.mem.Allocator, base_name: []const u8, form: []const u8) ![]u8 {
    const label = try arena.dupe(u8, form);
    var capitalize = true;
    for (label) |*char| {
        if (char.* == '-') {
            char.* = ' ';
            capitalize = true;
        } else {
            if (capitalize) char.* = std.ascii.toUpper(char.*);
            capitalize = false;
        }
    }
    return std.fmt.allocPrint(arena, "{s} ({s})", .{ base_name, label });
}
