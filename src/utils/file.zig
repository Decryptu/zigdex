const std = @import("std");

pub fn findProjectRoot() ![]const u8 {
    var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.os.getcwd(&buffer);

    // Check if we're in the project root (where assets directory exists)
    var dir = try std.fs.openDirAbsolute(cwd, .{});
    defer dir.close();

    dir.access("assets", .{}) catch |err| switch (err) {
        error.FileNotFound => {
            // Try parent directory
            if (std.fs.path.dirname(cwd)) |parent| {
                var parent_dir = try std.fs.openDirAbsolute(parent, .{});
                defer parent_dir.close();
                parent_dir.access("assets", .{}) catch return error.AssetsNotFound;
                return parent;
            }
            return error.AssetsNotFound;
        },
        else => return err,
    };

    return cwd;
}

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const project_root = try findProjectRoot();
    const full_path = try std.fs.path.join(allocator, &.{ project_root, path });
    defer allocator.free(full_path);

    const file = try std.fs.openFileAbsolute(full_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    errdefer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);
    if (bytes_read != file_size) {
        return error.IncompleteRead;
    }

    return buffer;
}
