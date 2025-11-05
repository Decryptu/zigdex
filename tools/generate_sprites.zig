const std = @import("std");

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

    try writer.writeAll("const std = @import(\"std\");\n\n");
    try writer.writeAll("pub const Pokemon = struct {\n");
    try writer.writeAll("    idx: u16,\n");
    try writer.writeAll("    slug: []const u8,\n");
    try writer.writeAll("    name: []const u8,\n");
    try writer.writeAll("    regular_sprite: []const u8,\n");
    try writer.writeAll("    shiny_sprite: []const u8,\n");
    try writer.writeAll("};\n\n");

    var pokemon_count: usize = 0;

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

        try writer.print("    .{{ .idx = {d}, .slug = \"{s}\", .name = \"{s}\",\n", .{ idx, slug, name_en });

        try writer.writeAll("      .regular_sprite = &[_]u8{");
        for (regular_sprite, 0..) |byte, i| {
            if (i > 0) try writer.writeAll(",");
            if (i % 16 == 0) try writer.writeAll("\n        ");
            try writer.print("{d}", .{byte});
        }
        try writer.writeAll("\n      },\n");

        try writer.writeAll("      .shiny_sprite = &[_]u8{");
        for (shiny_sprite, 0..) |byte, i| {
            if (i > 0) try writer.writeAll(",");
            if (i % 16 == 0) try writer.writeAll("\n        ");
            try writer.print("{d}", .{byte});
        }
        try writer.writeAll("\n      }");

        try writer.writeAll(" },\n");
        pokemon_count += 1;
    }

    try writer.writeAll("};\n\n");
    try writer.print("pub const pokemon_count = {d};\n", .{pokemon_count});

    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = output.items });
    std.debug.print("Generated {d} Pokemon sprites\n", .{pokemon_count});
}
