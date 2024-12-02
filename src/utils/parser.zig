const std = @import("std");

pub const PokemonName = struct {
    en: []const u8,
    ja: []const u8,
    fr: []const u8,
    de: []const u8,
    zh_hans: []const u8,
    zh_hant: []const u8,
};

pub const PokemonDesc = struct {
    en: []const u8,
    fr: []const u8,
    de: []const u8,
    ja: []const u8,
    zh_hans: []const u8,
    zh_hant: []const u8,
};

pub const Pokemon = struct {
    idx: u32,
    slug: []const u8,
    gen: u8,
    name: PokemonName,
    desc: PokemonDesc,
    forms: []const []const u8,
};

pub const PokemonList = struct {
    pokemons: []Pokemon,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *PokemonList) void {
        for (self.pokemons) |pokemon| {
            self.allocator.free(pokemon.slug);
            // Free other allocated memory as needed
        }
        self.allocator.free(self.pokemons);
    }
};

pub fn loadPokemonList(allocator: std.mem.Allocator) !PokemonList {
    const file = try std.fs.cwd().openFile("assets/pokemon.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);

    var token_stream = std.json.TokenStream.init(buffer);
    const options = std.json.ParseOptions{ .allocator = allocator };
    const pokemon_list = try std.json.parse([]Pokemon, &token_stream, options);

    return PokemonList{
        .pokemons = pokemon_list,
        .allocator = allocator,
    };
}

pub fn findPokemonByName(allocator: std.mem.Allocator, name: []const u8) !?Pokemon {
    var pokemon_list = try loadPokemonList(allocator);
    defer pokemon_list.deinit();

    for (pokemon_list.pokemons) |pokemon| {
        if (std.mem.eql(u8, std.ascii.lowerString(allocator, pokemon.slug) catch continue, std.ascii.lowerString(allocator, name) catch continue)) {
            return pokemon;
        }
    }
    return null;
}
