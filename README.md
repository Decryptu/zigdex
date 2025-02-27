# zigdex

```bash
src/
├── main.zig       # Entry point and argument handling
├── sprites.zig    # Sprite management and display 
└── args.zig       # Simple argument parser
build.zig         # Build script
```

## Key Features and Implementation Details

This implementation avoids embedding all sprites at compile time, which would significantly increase binary size with many Pokemon. Instead, it:

1. **Reads Sprites at Runtime**:
   - Retrieves the directory of the executable
   - Looks for sprites in the appropriate paths
   - Loads only what's needed when requested

2. **Fast Random Selection**:
   - Scans the directory once to get available Pokemon
   - Uses Zig's PRNG with nanosecond timestamp for randomness
   - Avoids loading all sprites into memory simultaneously

3. **Clean Error Handling**:
   - Provides clear error messages for common issues
   - Properly checks for file existence and readability
   - Handles memory resources correctly with proper deallocation

4. **Simple Command Processing**:
   - Lightweight argument parser without external dependencies
   - Supports all requested commands (`--random`, `--shiny`, specific Pokemon)

5. **Resource Management**:
   - Uses defer patterns to ensure resources are freed
   - Manages memory allocation properly with the GeneralPurposeAllocator

## Usage

1. Build the project:

    ```bash
    zig build
    ```

2. Run with various options:

    ```bash
    ./zig-out/bin/zigdex --random
    ./zig-out/bin/zigdex pikachu
    ./zig-out/bin/zigdex pikachu --shiny
    ```

The program expects your sprites to be in `assets/colorscripts/regular/` and `assets/colorscripts/shiny/` relative to the executable location.

This implementation is lightweight, straightforward, and fast enough to be used in shell startup scripts without noticeable delay.
