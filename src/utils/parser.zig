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
    pokemons: []const Pokemon,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const PokemonList) void {
        for (self.pokemons) |pokemon| {
            self.allocator.free(pokemon.slug);
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

    // Parse the JSON array
    var parsed = try std.json.parseFromSlice(
        []const std.json.Value,
        allocator,
        buffer,
        .{},
    );
    defer parsed.deinit();

    const root = parsed.value;
    var pokemon_list = try allocator.alloc(Pokemon, root.len);

    for (root, 0..) |item, i| {
        const obj = item.object;
        pokemon_list[i] = Pokemon{
            .idx = @intCast(obj.get("idx").?.integer),
            .slug = try allocator.dupe(u8, obj.get("slug").?.string),
            .gen = @intCast(obj.get("gen").?.integer),
            .name = PokemonName{
                .en = obj.get("name").?.object.get("en").?.string,
                .ja = obj.get("name").?.object.get("ja").?.string,
                .fr = obj.get("name").?.object.get("fr").?.string,
                .de = obj.get("name").?.object.get("de").?.string,
                .zh_hans = obj.get("name").?.object.get("zh_hans").?.string,
                .zh_hant = obj.get("name").?.object.get("zh_hant").?.string,
            },
            .desc = PokemonDesc{
                .en = obj.get("desc").?.object.get("en").?.string,
                .fr = obj.get("desc").?.object.get("fr").?.string,
                .de = obj.get("desc").?.object.get("de").?.string,
                .ja = obj.get("desc").?.object.get("ja").?.string,
                .zh_hans = obj.get("desc").?.object.get("zh_hans").?.string,
                .zh_hant = obj.get("desc").?.object.get("zh_hant").?.string,
            },
            .forms = &[_][]const u8{},
        };
    }

    return PokemonList{
        .pokemons = pokemon_list,
        .allocator = allocator,
    };
}

pub fn findPokemonByName(allocator: std.mem.Allocator, name: []const u8) !?Pokemon {
    var pokemon_list = try loadPokemonList(allocator);
    defer pokemon_list.deinit();

    const lower_name = try std.ascii.allocLowerString(allocator, name);
    defer allocator.free(lower_name);

    for (pokemon_list.pokemons) |pokemon| {
        const lower_slug = try std.ascii.allocLowerString(allocator, pokemon.slug);
        defer allocator.free(lower_slug);

        if (std.mem.eql(u8, lower_slug, lower_name)) {
            return pokemon;
        }
    }
    return null;
}
