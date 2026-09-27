const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gen_sprites = b.addExecutable(.{
        .name = "generate_sprites",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_sprites.zig"),
            .target = b.graph.host,
            // Compiles in well under a second, and its safety checks guard the sprite data.
            .optimize = .Debug,
        }),
    });

    const run_gen = b.addRunArtifact(gen_sprites);
    run_gen.addFileArg(b.path("assets/pokemon.json"));
    run_gen.addDirectoryArg(b.path("assets/colorscripts"));
    const sprites_dir = run_gen.addOutputDirectoryArg("sprites");

    const sprites = b.createModule(.{
        .root_source_file = sprites_dir.path(b, "embedded_sprites.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "zigdex",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
            .strip = optimize != .Debug,
            .imports = &.{.{ .name = "embedded_sprites", .module = sprites }},
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "embedded_sprites", .module = sprites }},
        }),
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
