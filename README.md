<div align="center">

# zigdex

<img width="128" height="128" alt="zigdex-logo" src="https://github.com/user-attachments/assets/203c4298-687c-4c72-b2ed-791f5768bab8" />

[![Zig](https://img.shields.io/badge/Zig-0.16.0-orange?logo=zig&logoColor=white)](https://ziglang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A fast, lightweight Pokemon sprite viewer for your terminal written in Zig.

<img width="834" alt="zigdex-screenshot" src="https://github.com/user-attachments/assets/c2ebf09a-51d8-46d1-923f-0160882262ef" />

</div>

## Features

- 🎲 Random Pokemon with 1/128 shiny chance
- ✨ Shiny variant support
- 🚀 Sprites embedded in binary (works offline)
- 📦 Single self-contained executable
- ⚡ Optimized for shell startup scripts

## Performance

Mean time of `random`, measured with `hyperfine -N --warmup 100 --runs 2000`:

| Command | macOS 27, Apple Silicon | Linux x86_64 |
|:---|---:|---:|
| `zigdex random` | 1.10 ms | 0.22 ms |
| `pokeget random` | 1.72 ms | 2.23 ms |
| `krabby random` | 4.07 ms | 6.84 ms |

```ascii
macOS
zigdex   ▓▓▓░░░░░░░  1.10ms  ← 3.7x faster than krabby
pokeget  ▓▓▓▓░░░░░░  1.72ms
krabby   ▓▓▓▓▓▓▓▓▓▓  4.07ms
```

<sub>For reference, `/usr/bin/true` takes 0.72 ms and an empty compiled C program about 1.0 ms on the same Mac. Linux runs used pokeget 1.6.7 and krabby 0.3.0, pinned to one core.</sub>

## Installation

### Homebrew (macOS)

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
zig build test
```

This will:

1. Generate embedded sprites from your `assets/` directory at compile time
2. Create a single executable at `zig-out/bin/zigdex`
3. Embed all 1025 Pokemon sprites and 447 alternate forms directly into the binary

## Usage

```bash
# Random Pokemon (1/128 chance for shiny)
zigdex random
zigdex --random

# Specific Pokemon by name
zigdex pikachu
zigdex bulbasaur charmander squirtle

# By Pokedex number
zigdex 25
zigdex 1 4 7

# Force shiny variant
zigdex pikachu --shiny
zigdex random --shiny

# Hide Pokemon name
zigdex pikachu --hide-name
zigdex random --hide-name
```

## Shell Integration

Add to your `.zshrc` or `.bashrc`:

```bash
# Show random Pokemon on terminal start
zigdex --random --hide-name

# Or with fastfetch
alias fastfetch='zigdex --random --hide-name | command fastfetch --logo-type file-raw --logo -'
```

*Note: [fastfetch](https://github.com/fastfetch-cli/fastfetch) is a fast system information tool similar to neofetch.*

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

- The `generate_sprites.zig` tool runs during the build and replays each ANSI sprite into a pixel grid
- Every sprite is stored as a palette plus two pixels per cell, with 256-color sprites converted to truecolor and transparent borders cropped
- Each Pokemon's regular and shiny sprites share one deflate stream, and all streams are embedded as a single blob
- At runtime the sprite is inflated and drawn with half blocks, emitting only the color changes each cell needs and resetting colors at every line end
- No runtime filesystem dependencies
- Binary size: ~1.2MB (fully self-contained)

### Fast Random Selection

- Seeded from OS entropy
- 1/128 chance for shiny (mimicking main series games)
- O(1) lookup by index
- Zero filesystem I/O at runtime

### Pokemon Lookup

Supports multiple lookup methods:

- Case-insensitive name matching (`pikachu`, `PIKACHU`, `"Charizard (Mega X)"`)
- Slug matching (`charizard-mega-x`)
- Pokedex number (`25`, `150`)

Names and slugs are resolved with a binary search over a table sorted at build time. Unknown names are reported on stderr and make `zigdex` exit with status 1.

### Startup

- Uses Zig's minimal entry point: no environment map, allocator or thread pool is set up
- Writes straight to the file descriptor instead of going through `std.Io`, so on macOS dyld resolves only a handful of libSystem symbols at launch
- Lookup tables store offsets rather than pointers, leaving almost nothing for dyld to rebase
- No heap allocation at runtime
- A handful of system calls per run, with the sprite written in a single `write`

## Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--random` | `-r` | Display random Pokemon (1/128 shiny) |
| `--shiny` | `-s` | Force shiny variant |
| `--hide-name` | | Don't print Pokemon name |
| `--help` | `-h` | Show help message |

## Requirements

- Zig 0.16.x
- Terminal with ANSI color support
- Pokemon sprite assets in `assets/` directory

## Recommended Terminals

For the best experience, we recommend using:

- [iTerm2](https://iterm2.com/) - Works great with zigdex
- [Ghostty](https://ghostty.org/) - Works great with zigdex

Both terminals provide excellent ANSI color support and render Pokemon sprites beautifully.

## License

MIT
