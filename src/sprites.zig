const std = @import("std");
const builtin = @import("builtin");

const REGULAR_SPRITES_PATH = "assets/colorscripts/regular";
const SHINY_SPRITES_PATH = "assets/colorscripts/shiny";

fn getProjectPath(allocator: std.mem.Allocator) ![]const u8 {
    return std.process.getCwdAlloc(allocator);
}

fn getSpritePath(allocator: std.mem.Allocator, name: []const u8, shiny: bool) ![]const u8 {
    const project_dir = try getProjectPath(allocator);
    defer allocator.free(project_dir);

    const base_dir = if (shiny) SHINY_SPRITES_PATH else REGULAR_SPRITES_PATH;
    return try std.fs.path.join(allocator, &[_][]const u8{ project_dir, base_dir, name });
}

pub fn getSprite(allocator: std.mem.Allocator, name: []const u8, shiny: bool) ![]const u8 {
    const sprite_path = try getSpritePath(allocator, name, shiny);
    defer allocator.free(sprite_path);

    const file = std.fs.openFileAbsolute(sprite_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Pokemon '{s}' not found\n", .{name});
            return error.PokemonNotFound;
        }
        return err;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const content = try allocator.alloc(u8, file_size);
    const bytes_read = try file.readAll(content);

    if (bytes_read != file_size) {
        allocator.free(content);
        return error.ReadError;
    }

    return content;
}

fn getAvailableSprites(allocator: std.mem.Allocator, shiny: bool) ![][]const u8 {
    const project_dir = try getProjectPath(allocator);
    defer allocator.free(project_dir);

    const base_dir = if (shiny) SHINY_SPRITES_PATH else REGULAR_SPRITES_PATH;
    const dir_path = try std.fs.path.join(allocator, &[_][]const u8{ project_dir, base_dir });
    defer allocator.free(dir_path);

    var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Sprite directory not found: {s}\n", .{dir_path});
            std.debug.print("Make sure you have the assets directory in your current working directory.\n", .{});
            return error.SpriteDirectoryNotFound;
        }
        return err;
    };
    defer dir.close();

    var sprites = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    errdefer {
        for (sprites.items) |item| {
            allocator.free(item);
        }
        sprites.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file) {
            const name = try allocator.dupe(u8, entry.name);
            try sprites.append(allocator, name);
        }
    }

    return sprites.toOwnedSlice(allocator);
}

pub fn displayRandom(allocator: std.mem.Allocator, shiny: bool) !void {
    const sprites_list = try getAvailableSprites(allocator, shiny);
    defer {
        for (sprites_list) |sprite| {
            allocator.free(sprite);
        }
        allocator.free(sprites_list);
    }

    if (sprites_list.len == 0) {
        return error.NoSpritesFound;
    }

    var prng = std.Random.DefaultPrng.init(@as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))));
    const random = prng.random();

    const index = random.intRangeAtMost(usize, 0, sprites_list.len - 1);
    const pokemon_name = sprites_list[index];

    const sprite_content = try getSprite(allocator, pokemon_name, shiny);
    defer allocator.free(sprite_content);

    try std.fs.File.stdout().writeAll(sprite_content);
}

pub fn display(allocator: std.mem.Allocator, name: []const u8, shiny: bool) !void {
    const sprite_content = try getSprite(allocator, name, shiny);
    defer allocator.free(sprite_content);

    try std.fs.File.stdout().writeAll(sprite_content);
}
