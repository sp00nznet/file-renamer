# Media Renamer

A bash script that renames movie and TV show files using metadata from [TMDB](https://www.themoviedb.org/).

**Output formats:**
- Movies: `Movie Name (Year).ext`
- TV Shows: `Show Name - S01E02 - Episode Title.ext`

## Quick Start

1. Install dependencies:
   ```bash
   sudo apt install curl jq   # Debian/Ubuntu
   brew install curl jq       # macOS
   ```

2. Get a free API key at https://www.themoviedb.org/settings/api

3. Run the interactive launcher:
   ```bash
   ./rename.sh
   ```

   Or run directly:
   ```bash
   ./file_renamer.sh -k YOUR_API_KEY /path/to/media
   ```

## Interactive Mode

Run `./rename.sh` for a guided experience that will prompt you for:
- Media type (Movies, TV Shows, or Auto-detect)
- Target directory
- Dry run option
- Logging preferences

## Command Line Usage

```bash
./file_renamer.sh [options] [directory]
```

| Option | Description |
|--------|-------------|
| `-h` | Show help |
| `-k KEY` | Set TMDB API key |
| `-m MODE` | Mode: `movies`, `tv`, or `auto` (default) |
| `-d` | Dry run (preview only) |
| `-l FILE` | Log operations to file |

**Examples:**
```bash
./file_renamer.sh /path/to/media              # Auto-detect
./file_renamer.sh -m movies /path/to/media    # Movies only
./file_renamer.sh -m tv /path/to/media        # TV shows only
./file_renamer.sh -d /path/to/media           # Preview changes
```

## Supported Formats

**Video extensions:** mkv, mp4, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, ts, vob

**TV show patterns:** `S01E02`, `1x02`, `Season.1.Episode.2`

See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed information.

## License

MIT License
