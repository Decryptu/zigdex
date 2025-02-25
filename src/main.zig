const std = @import("std");
const sprites = @import("sprites.zig");
const args_module = @import("args.zig");

pub fn main() !void {
    // Initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    var args = try args_module.parse(allocator);
    defer args.deinit();

    // Show help if requested or no action specified
    if (args.help or (!args.random and args.pokemon_name == null)) {
        try args_module.printUsage(std.io.getStdOut().writer());
        return;
    }

    // Handle random Pokemon display
    if (args.random) {
        sprites.displayRandom(allocator, args.shiny) catch |err| {
            std.debug.print("Error: {s}\n", .{@errorName(err)});
            return err;
        };
        return;
    }

    // Handle specific Pokemon display
    if (args.pokemon_name) |name| {
        sprites.display(allocator, name, args.shiny) catch |err| {
            if (err == error.PokemonNotFound) {
                std.debug.print("Pokemon '{s}' not found.\n", .{name});
                return err;
            } else {
                std.debug.print("Error: {s}\n", .{@errorName(err)});
                return err;
            }
        };
        return;
    }
}
