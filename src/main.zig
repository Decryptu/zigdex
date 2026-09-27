const std = @import("std");
const sprites = @import("sprites.zig");
const cli = @import("args.zig");

// The minimal entry point skips building the environment map, allocators and a threaded Io
// that std.process.Init would set up, which otherwise dominates the runtime.
pub fn main(init: std.process.Init.Minimal) !u8 {
    const io = std.Io.Threaded.global_single_threaded.io();
    const argv = init.args.vector;
    const args_only = argv[@min(argv.len, 1)..];
    const args = cli.parse(args_only);

    // Large enough that a sprite usually leaves in a single write.
    var buf: [32 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buf);
    const w = &stdout.interface;

    if (args.help or (!args.random and args.name_count == 0)) {
        try w.writeAll(cli.usage);
        try w.flush();
        return 0;
    }

    if (args.random) {
        var seed: u64 = undefined;
        io.random(std.mem.asBytes(&seed));
        const pokemon, const shiny = sprites.randomPokemon(seed);
        try sprites.write(w, pokemon, shiny or args.shiny, args.hide_name);
        try w.flush();
        return 0;
    }

    var status: u8 = 0;
    for (args_only) |ptr| {
        const name = std.mem.span(ptr);
        if (!cli.isName(name)) continue;
        const pokemon = sprites.findPokemon(name) orelse {
            try w.flush();
            var err_buf: [256]u8 = undefined;
            var stderr = std.Io.File.stderr().writerStreaming(io, &err_buf);
            try stderr.interface.print("Pokemon '{s}' not found.\n", .{name});
            try stderr.interface.flush();
            status = 1;
            continue;
        };
        try sprites.write(w, pokemon, args.shiny, args.hide_name);
    }
    try w.flush();
    return status;
}

test "CLI parsing" {
    const argv = [_][*:0]const u8{ "pikachu", "--shiny", "random", "--hide-name", "25" };
    const args = cli.parse(&argv);
    try std.testing.expectEqual(2, args.name_count);
    try std.testing.expect(args.shiny and args.random and args.hide_name and !args.help);
    try std.testing.expect(cli.isName("pikachu"));
    try std.testing.expect(!cli.isName("-s"));
}

test "Pokemon lookup" {
    const pikachu = sprites.findPokemon("25").?;
    try std.testing.expectEqualStrings("pikachu", pikachu.slug);
    try std.testing.expect(pikachu == sprites.findPokemon("PIKACHU").?);
    try std.testing.expectEqualStrings("charizard-mega-x", sprites.findPokemon("charizard-mega-x").?.slug);
    try std.testing.expectEqualStrings("charizard-mega-x", sprites.findPokemon("Charizard (Mega X)").?.slug);
    try std.testing.expectEqualStrings("mr-mime", sprites.findPokemon("Mr. Mime").?.slug);
    try std.testing.expectEqual(1025, sprites.findPokemon("1025").?.idx);
    try std.testing.expect(sprites.findPokemon("0") == null);
    try std.testing.expect(sprites.findPokemon("1026") == null);
    try std.testing.expect(sprites.findPokemon("definitely-not-a-pokemon") == null);
}

test "sprites render the regular or shiny variant" {
    const pikachu = sprites.findPokemon("pikachu").?;
    var regular_buf: [64 * 1024]u8 = undefined;
    var regular: std.Io.Writer = .fixed(&regular_buf);
    try sprites.write(&regular, pikachu, false, false);
    var shiny_buf: [64 * 1024]u8 = undefined;
    var shiny: std.Io.Writer = .fixed(&shiny_buf);
    try sprites.write(&shiny, pikachu, true, true);

    try std.testing.expect(std.mem.startsWith(u8, regular.buffered(), "Pikachu\n     \x1b[38;2;0;0;0m▄\x1b[48;2;65;65;65m▀\x1b[48;2;0;0;0m▀\x1b[49m         ▄▄  \x1b[0m\n"));
    const regular_art = regular.buffered()["Pikachu\n".len..];
    try std.testing.expectEqual(std.mem.count(u8, regular_art, "\n"), std.mem.count(u8, shiny.buffered(), "\n"));
    try std.testing.expect(!std.mem.eql(u8, regular_art, shiny.buffered()));
    try std.testing.expect(std.mem.endsWith(u8, shiny.buffered(), "\x1b[0m\n"));
}
