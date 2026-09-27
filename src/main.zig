const std = @import("std");
const builtin = @import("builtin");
const sprites = @import("sprites.zig");
const cli = @import("args.zig");

// std.debug and std.log write through a threaded Io by default, which keeps its whole vtable in
// every binary. Release builds swap in the stub Io, so a panic still aborts but prints nothing.
pub const std_options_debug_threaded_io: ?*std.Io.Threaded = if (builtin.mode == .Debug) std.Io.Threaded.global_single_threaded else null;
pub const std_options_debug_io: std.Io = if (builtin.mode == .Debug) std.Io.Threaded.global_single_threaded.io() else .failing;

// The minimal entry point skips the environment map, allocators and threaded Io that
// std.process.Init sets up. std.Io is avoided entirely: on macOS its vtable imports about a
// hundred libSystem functions that dyld resolves at every launch, costing more than the rest of
// the run.
pub fn main(init: std.process.Init.Minimal) u8 {
    return run(init.args.vector) catch |err| {
        var buf: [64]u8 = undefined;
        var stderr: FdWriter = .init(std.posix.STDERR_FILENO, &buf);
        stderr.interface.print("zigdex: {t}\n", .{err}) catch {};
        stderr.interface.flush() catch {};
        return 1;
    };
}

fn run(argv: []const [*:0]const u8) !u8 {
    const args_only = argv[@min(argv.len, 1)..];
    const args = cli.parse(args_only);

    // Large enough that a sprite usually leaves in a single write.
    var buf: [32 * 1024]u8 = undefined;
    var stdout: FdWriter = .init(std.posix.STDOUT_FILENO, &buf);
    const w = &stdout.interface;

    if (args.help or (!args.random and args.name_count == 0)) {
        try w.writeAll(cli.usage);
        try w.flush();
        return 0;
    }

    if (args.random) {
        const pokemon, const shiny = sprites.randomPokemon(randomSeed());
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
            var stderr: FdWriter = .init(std.posix.STDERR_FILENO, &err_buf);
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

fn randomSeed() u64 {
    var seed: u64 = undefined;
    const bytes = std.mem.asBytes(&seed);
    switch (builtin.os.tag) {
        .linux => _ = std.os.linux.getrandom(bytes, bytes.len, 0),
        else => std.c.arc4random_buf(bytes, bytes.len),
    }
    return seed;
}

const FdWriter = struct {
    fd: std.posix.fd_t,
    interface: std.Io.Writer,

    fn init(fd: std.posix.fd_t, buffer: []u8) FdWriter {
        return .{ .fd = fd, .interface = .{ .buffer = buffer, .vtable = &.{ .drain = drain } } };
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const fd = @as(*FdWriter, @alignCast(@fieldParentPtr("interface", w))).fd;
        try writeAll(fd, w.buffered());
        w.end = 0;
        var n: usize = 0;
        for (data[0 .. data.len - 1]) |bytes| {
            try writeAll(fd, bytes);
            n += bytes.len;
        }
        for (0..splat) |_| {
            try writeAll(fd, data[data.len - 1]);
            n += data[data.len - 1].len;
        }
        return n;
    }

    fn writeAll(fd: std.posix.fd_t, bytes: []const u8) std.Io.Writer.Error!void {
        var rest = bytes;
        while (rest.len > 0) {
            const rc = std.posix.system.write(fd, rest.ptr, rest.len);
            switch (std.posix.errno(rc)) {
                .SUCCESS => rest = rest[@intCast(rc)..],
                .INTR => {},
                else => return error.WriteFailed,
            }
        }
    }
};

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
    try std.testing.expectEqualStrings("pikachu", sprites.text(pikachu.slug));
    try std.testing.expect(pikachu == sprites.findPokemon("PIKACHU").?);
    try std.testing.expectEqualStrings("charizard-mega-x", sprites.text(sprites.findPokemon("charizard-mega-x").?.slug));
    try std.testing.expectEqualStrings("charizard-mega-x", sprites.text(sprites.findPokemon("Charizard (Mega X)").?.slug));
    try std.testing.expectEqualStrings("mr-mime", sprites.text(sprites.findPokemon("Mr. Mime").?.slug));
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
