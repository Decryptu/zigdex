const std = @import("std");
const commands = @import("commands/random.zig");
const display = @import("commands/display.zig");
const parser = @import("utils/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    // Parse arguments and execute commands
    try handleCommand(allocator, args);
}

fn handleCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const command = args[1];

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printUsage();
        return;
    }

    if (std.mem.eql(u8, command, "--random") or std.mem.eql(u8, command, "-r")) {
        try commands.displayRandomPokemon(allocator);
        return;
    }

    // Handle specific pokemon display
    try display.showPokemon(allocator, command);
}

fn printUsage() !void {
    const usage =
        \\Usage: zigdex [options] [pokemon]
        \\
        \\Options:
        \\  -r, --random    Display a random pokemon
        \\  -h, --help      Display this help message
        \\
        \\Examples:
        \\  zigdex pikachu
        \\  zigdex --random
        \\
    ;
    try std.io.getStdOut().writeAll(usage);
}
