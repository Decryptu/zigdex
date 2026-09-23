const std = @import("std");
const c = @cImport({
    @cInclude("zlib.h");
});

fn compressData(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var dest_len: c.uLongf = @intCast(c.compressBound(@intCast(input.len)));
    const dest = try allocator.alloc(u8, @intCast(dest_len));

    const ret = c.compress2(dest.ptr, &dest_len, input.ptr, @intCast(input.len), 9);
    if (ret != c.Z_OK) return error.CompressionFailed;

    // Resize to actual compressed size
    return try allocator.realloc(dest, @intCast(dest_len));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        std.debug.print("Usage: {s} <pokemon.json> <colorscripts_dir> <output.zig>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const json_path = args[1];
    const sprites_dir = args[2];
    const output_path = args[3];

    const json_data = try std.fs.cwd().readFileAlloc(allocator, json_path, 10 * 1024 * 1024);
    defer allocator.free(json_data);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_data, .{});
    defer parsed.deinit();

    const pokemon_array = parsed.value.array;

    var output = try std.ArrayList(u8).initCapacity(allocator, 1024 * 1024);
    defer output.deinit(allocator);
    const writer = output.writer(allocator);

    try writer.writeAll("pub const Pokemon = struct {\n");
    try writer.writeAll("    idx: u16,\n");
    try writer.writeAll("    slug: []const u8,\n");
    try writer.writeAll("    name: []const u8,\n");
    try writer.writeAll("    regular_sprite: []const u8,\n");
    try writer.writeAll("    shiny_sprite: []const u8,\n");
    try writer.writeAll("};\n\n");

    var pokemon_count: usize = 0;
    var form_count: usize = 0;
    var total_raw: usize = 0;
    var total_compressed: usize = 0;

    try writer.writeAll("pub const pokemon_list = [_]Pokemon{\n");

    for (pokemon_array.items) |item| {
        const obj = item.object;
        const idx = @as(u16, @intCast(obj.get("idx").?.integer));
        const slug = obj.get("slug").?.string;
        const name_obj = obj.get("name").?.object;
        const name_en = name_obj.get("en").?.string;

        const regular_path = try std.fmt.allocPrint(allocator, "{s}/regular/{s}", .{ sprites_dir, slug });
        defer allocator.free(regular_path);

        const shiny_path = try std.fmt.allocPrint(allocator, "{s}/shiny/{s}", .{ sprites_dir, slug });
        defer allocator.free(shiny_path);

        const regular_sprite = std.fs.cwd().readFileAlloc(allocator, regular_path, 100 * 1024) catch |err| {
            std.debug.print("Warning: Could not read {s}: {}\n", .{ regular_path, err });
            continue;
        };
        defer allocator.free(regular_sprite);

        const shiny_sprite = std.fs.cwd().readFileAlloc(allocator, shiny_path, 100 * 1024) catch |err| {
            std.debug.print("Warning: Could not read {s}: {}\n", .{ shiny_path, err });
            continue;
        };
        defer allocator.free(shiny_sprite);

        // Compress sprites with zlib
        const regular_compressed = try compressData(allocator, regular_sprite);
        defer allocator.free(regular_compressed);

        const shiny_compressed = try compressData(allocator, shiny_sprite);
        defer allocator.free(shiny_compressed);

        total_raw += regular_sprite.len + shiny_sprite.len;
        total_compressed += regular_compressed.len + shiny_compressed.len;

        try writePokemon(writer, idx, slug, name_en, regular_compressed, shiny_compressed);
        pokemon_count += 1;
    }

    try writer.writeAll("};\n\n");
    try writer.writeAll("pub const pokemon_forms = [_]Pokemon{\n");

    for (pokemon_array.items) |item| {
        const obj = item.object;
        const idx = @as(u16, @intCast(obj.get("idx").?.integer));
        const base_slug = obj.get("slug").?.string;
        const base_name = obj.get("name").?.object.get("en").?.string;
        const forms = obj.get("forms") orelse continue;

        for (forms.array.items) |form_value| {
            const form = form_value.string;
            const slug = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ base_slug, form });
            defer allocator.free(slug);
            const display_name = try formDisplayName(allocator, base_name, form);
            defer allocator.free(display_name);

            const regular_path = try std.fmt.allocPrint(allocator, "{s}/regular/{s}", .{ sprites_dir, slug });
            defer allocator.free(regular_path);
            const shiny_path = try std.fmt.allocPrint(allocator, "{s}/shiny/{s}", .{ sprites_dir, slug });
            defer allocator.free(shiny_path);

            const regular_sprite = std.fs.cwd().readFileAlloc(allocator, regular_path, 100 * 1024) catch |err| {
                std.debug.print("Warning: Could not read {s}: {}\n", .{ regular_path, err });
                continue;
            };
            defer allocator.free(regular_sprite);
            const shiny_sprite = std.fs.cwd().readFileAlloc(allocator, shiny_path, 100 * 1024) catch |err| blk: {
                std.debug.print("Warning: Could not read {s}; using regular sprite for shiny: {}\n", .{ shiny_path, err });
                break :blk regular_sprite;
            };
            defer if (shiny_sprite.ptr != regular_sprite.ptr) allocator.free(shiny_sprite);

            const regular_compressed = try compressData(allocator, regular_sprite);
            defer allocator.free(regular_compressed);
            const shiny_compressed = try compressData(allocator, shiny_sprite);
            defer allocator.free(shiny_compressed);

            total_raw += regular_sprite.len + shiny_sprite.len;
            total_compressed += regular_compressed.len + shiny_compressed.len;
            try writePokemon(writer, idx, slug, display_name, regular_compressed, shiny_compressed);
            form_count += 1;
        }
    }

    try writer.writeAll("};\n\n");
    try writer.print("pub const pokemon_count = {d};\n", .{pokemon_count});
    try writer.print("pub const pokemon_form_count = {d};\n", .{form_count});

    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = output.items });
    std.debug.print("Generated {d} Pokemon and {d} form sprites (raw: {d} KB, compressed: {d} KB, ratio: {d:.1}x)\n", .{
        pokemon_count,
        form_count,
        total_raw / 1024,
        total_compressed / 1024,
        @as(f64, @floatFromInt(total_raw)) / @as(f64, @floatFromInt(total_compressed)),
    });
}

fn writePokemon(writer: anytype, idx: u16, slug: []const u8, name: []const u8, regular: []const u8, shiny: []const u8) !void {
    try writer.print("    .{{ .idx = {d}, .slug = \"{s}\", .name = \"{s}\",\n", .{ idx, slug, name });
    try writeSprite(writer, "regular_sprite", regular);
    try writer.writeAll(",\n");
    try writeSprite(writer, "shiny_sprite", shiny);
    try writer.writeAll(" },\n");
}

fn writeSprite(writer: anytype, field: []const u8, sprite: []const u8) !void {
    try writer.print("      .{s} = &[_]u8{{", .{field});
    for (sprite, 0..) |byte, i| {
        if (i > 0) try writer.writeAll(",");
        if (i % 16 == 0) try writer.writeAll("\n        ");
        try writer.print("{d}", .{byte});
    }
    try writer.writeAll("\n      }");
}

fn formDisplayName(allocator: std.mem.Allocator, base_name: []const u8, form: []const u8) ![]u8 {
    const label = try allocator.alloc(u8, form.len);
    defer allocator.free(label);
    var capitalize = true;
    for (form, 0..) |char, i| {
        if (char == '-') {
            label[i] = ' ';
            capitalize = true;
        } else {
            label[i] = if (capitalize) std.ascii.toUpper(char) else char;
            capitalize = false;
        }
    }
    return std.fmt.allocPrint(allocator, "{s} ({s})", .{ base_name, label });
}
