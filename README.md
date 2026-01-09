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

3. Run:
   ```bash
   chmod +x file_renamer.sh
   ./file_renamer.sh -k YOUR_API_KEY /path/to/media
   ```

## Usage

```bash
./file_renamer.sh [options] [directory]
```

| Option | Description |
|--------|-------------|
| `-h` | Show help |
| `-k KEY` | Set TMDB API key |
| `-d` | Dry run (preview only) |
| `-l FILE` | Log operations to file |

**Examples:**
```bash
./file_renamer.sh /path/to/media                    # Basic usage
./file_renamer.sh -d /path/to/media                 # Preview changes
./file_renamer.sh -l rename.log /path/to/media      # With logging
```

You can also set the API key via environment variable:
```bash
export TMDB_API_KEY=your_key
```

## Supported Formats

**Video extensions:** mkv, mp4, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, ts, vob

**TV show patterns:** `S01E02`, `1x02`, `Season.1.Episode.2`

See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed information.

## License

MIT License
