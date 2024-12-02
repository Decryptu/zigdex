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

fn getOptionalString(value: ?std.json.Value, default: []const u8) []const u8 {
    if (value) |val| {
        return val.string;
    }
    return default;
}

pub fn loadPokemonList(allocator: std.mem.Allocator) !PokemonList {
    const file = try std.fs.cwd().openFile("assets/pokemon.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);

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
        const name_obj = obj.get("name").?.object;
        const desc_obj = if (obj.get("desc")) |desc| desc.object else return error.MissingDesc;

        pokemon_list[i] = Pokemon{
            .idx = @intCast(obj.get("idx").?.integer),
            .slug = try allocator.dupe(u8, obj.get("slug").?.string),
            .gen = @intCast(obj.get("gen").?.integer),
            .name = PokemonName{
                .en = getOptionalString(name_obj.get("en"), "Unknown"),
                .ja = getOptionalString(name_obj.get("ja"), ""),
                .fr = getOptionalString(name_obj.get("fr"), ""),
                .de = getOptionalString(name_obj.get("de"), ""),
                .zh_hans = getOptionalString(name_obj.get("zh_hans"), ""),
                .zh_hant = getOptionalString(name_obj.get("zh_hant"), ""),
            },
            .desc = PokemonDesc{
                .en = getOptionalString(desc_obj.get("en"), "No description available."),
                .fr = getOptionalString(desc_obj.get("fr"), ""),
                .de = getOptionalString(desc_obj.get("de"), ""),
                .ja = getOptionalString(desc_obj.get("ja"), ""),
                .zh_hans = getOptionalString(desc_obj.get("zh_hans"), ""),
                .zh_hant = getOptionalString(desc_obj.get("zh_hant"), ""),
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
