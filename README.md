# zigdex

A fast, lightweight Pokemon sprite viewer for your terminal written in Zig.

<img width="834" height="568" alt="zigdex-screenshot" src="https://github.com/user-attachments/assets/c2ebf09a-51d8-46d1-923f-0160882262ef" />

## Features

- 🎲 Random Pokemon with 1/128 shiny chance
- ✨ Shiny variant support
- 🚀 Sprites embedded in binary (works offline)
- 📦 Single self-contained executable
- ⚡ Optimized for shell startup scripts

## Installation

### Homebrew (macOS/Linux)

```bash
brew tap Decryptu/tap
brew install zigdex
```

*Note: While zigdex is being reviewed for inclusion in Homebrew core, you can install it from my personal tap.*

### Manual Installation

Download the appropriate binary for your architecture from the [releases page](https://github.com/Decryptu/zigdex/releases) and add it to your PATH.

## Building

```bash
zig build
```

This will:

1. Generate embedded sprites from your `assets/` directory at compile time
2. Create a single executable at `zig-out/bin/zigdex`
3. Embed all 1010+ Pokemon sprites directly into the binary

## Usage

```bash
# Random Pokemon (1/128 chance for shiny)
zigdex --random

# Specific Pokemon by name
zigdex pikachu
zigdex bulbasaur charmander squirtle

# By Pokedex number
zigdex 25
zigdex 1 4 7

# Force shiny variant
zigdex pikachu --shiny
zigdex --random --shiny

# Hide Pokemon name
zigdex pikachu --hide-name
zigdex --random --hide-name
```

## Shell Integration

Add to your `.zshrc` or `.bashrc`:

```bash
# Show random Pokemon on terminal start
zigdex --random --hide-name

# Or with fastfetch
alias fastfetch='zigdex --random --hide-name | command fastfetch --logo-type file-raw --logo -'
```

## Project Structure

```tree
zigdex/
├── src/
│   ├── main.zig       # Entry point and CLI
│   ├── args.zig       # Argument parser
│   └── sprites.zig    # Pokemon lookup and display
├── tools/
│   └── generate_sprites.zig  # Build-time sprite embedder
├── assets/
│   ├── pokemon.json
│   └── colorscripts/
│       ├── regular/   # Normal sprites
│       └── shiny/     # Shiny variants
└── build.zig
```

## Implementation Details

### Compile-Time Sprite Embedding

- Sprites are converted to byte arrays at compile time
- The `generate_sprites.zig` tool runs during build
- Creates `embedded_sprites.zig` with all Pokemon data
- No runtime filesystem dependencies
- Binary size: ~50-100MB (fully self-contained)

### Fast Random Selection

- Uses `std.Random.DefaultPrng` with nanosecond seed
- 1/128 chance for shiny (mimicking main series games)
- O(1) lookup by index
- Zero filesystem I/O at runtime

### Pokemon Lookup

Supports multiple lookup methods:

- Case-insensitive name matching (`pikachu`, `PIKACHU`)
- Slug matching (`charizard-mega-x`)
- Pokedex number (`25`, `150`)

### Memory Management

- Uses `GeneralPurposeAllocator` for safety
- Proper `defer` patterns for cleanup
- No memory leaks in debug builds
- Efficient argument parsing

## Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--random` | `-r` | Display random Pokemon (1/128 shiny) |
| `--shiny` | `-s` | Force shiny variant |
| `--hide-name` | | Don't print Pokemon name |
| `--help` | `-h` | Show help message |

## Requirements

- Zig 0.15.2 or later
- Terminal with ANSI color support
- Pokemon sprite assets in `assets/` directory

## License

MIT
