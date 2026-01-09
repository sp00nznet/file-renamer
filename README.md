# Media Renamer

A bash script that automatically renames movie and TV show files using metadata from [The Movie Database (TMDB)](https://www.themoviedb.org/).

## Features

- **Movie Renaming**: Renames movie files to `Movie Name (Year).ext`
- **TV Show Renaming**: Renames TV episodes to `Show Name - S01E02 - Episode Title.ext`
- **Automatic Detection**: Distinguishes between movies and TV shows based on filename patterns
- **TMDB Integration**: Fetches accurate metadata including titles, years, and episode names
- **Interactive Selection**: Presents multiple matches for user selection
- **Dry Run Mode**: Preview changes before applying them
- **Logging**: Optional logging of all operations to a file
- **Smart Filename Parsing**: Strips quality indicators, release groups, and other noise from filenames

## Requirements

- **bash** (version 4.0+)
- **curl** - For API requests
- **jq** - For JSON parsing
- **TMDB API Key** - Free at https://www.themoviedb.org/settings/api

### Installing Dependencies

**Debian/Ubuntu:**
```bash
sudo apt install curl jq
```

**macOS (Homebrew):**
```bash
brew install curl jq
```

**Fedora/RHEL:**
```bash
sudo dnf install curl jq
```

## Installation

1. Clone or download the script:
   ```bash
   git clone https://github.com/yourusername/file-renamer.git
   cd file-renamer
   ```

2. Make the script executable:
   ```bash
   chmod +x file_renamer.sh
   ```

3. Get a free TMDB API key at https://www.themoviedb.org/settings/api

## Usage

```bash
./file_renamer.sh [options] [directory]
```

### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-k, --key KEY` | Set TMDB API key |
| `-d, --dry-run` | Preview changes without renaming files |
| `-l, --log FILE` | Enable logging to specified file |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `TMDB_API_KEY` | Your TMDB API key (alternative to `-k` flag) |

### Examples

**Basic usage:**
```bash
./file_renamer.sh /path/to/media
```

**With API key:**
```bash
./file_renamer.sh -k your_api_key /path/to/media
```

**Using environment variable:**
```bash
export TMDB_API_KEY=your_api_key
./file_renamer.sh /path/to/media
```

**Dry run (preview only):**
```bash
./file_renamer.sh -d /path/to/media
```

**With logging:**
```bash
./file_renamer.sh -l rename.log /path/to/media
```

**Combined options:**
```bash
./file_renamer.sh -k your_key -l rename.log -d /path/to/media
```

## Supported File Formats

The script processes the following video file extensions:

- `mkv`, `mp4`, `avi`, `mov`, `wmv`, `flv`
- `webm`, `m4v`, `mpg`, `mpeg`, `ts`, `vob`
- `divx`, `xvid`

## Filename Patterns

### TV Shows

The script recognizes these TV show patterns:

| Pattern | Example |
|---------|---------|
| `S01E02` | `Breaking.Bad.S01E02.720p.BluRay.mkv` |
| `1x02` | `Breaking.Bad.1x02.HDTV.mkv` |
| `Season.1.Episode.2` | `Breaking Bad Season 1 Episode 2.mkv` |

**Output format:** `Breaking Bad - S01E02 - Cat's in the Bag....mkv`

### Movies

Any video file without TV show patterns is treated as a movie.

| Input | Output |
|-------|--------|
| `The.Matrix.1999.BluRay.1080p.x264.mkv` | `The Matrix (1999).mkv` |
| `Inception.2010.REMASTERED.720p.mkv` | `Inception (2010).mkv` |

## Stripped Indicators

The script automatically removes these from filenames before searching:

- **Quality**: 720p, 1080p, 2160p, 4K, UHD, HDR
- **Source**: BluRay, BRRip, DVDRip, WebRip, Web-DL, HDTV
- **Codec**: x264, x265, H.264, H.265, HEVC, XviD, DivX
- **Audio**: AAC, AC3, DTS, 5.1, 7.1
- **Release**: Proper, Repack, Extended, Unrated, Remastered
- **Groups**: YIFY, YTS, RARBG, EZTV, and many others

## Interactive Workflow

1. The script scans the target directory for video files
2. For each file:
   - Detects if it's a movie or TV show
   - Searches TMDB for matches
   - Displays up to 5 results with ratings and descriptions
   - Prompts for selection:
     - `1-5`: Select a match
     - `n`: Perform a new search
     - `s`: Skip the file
3. Confirms the rename before applying
4. Displays a summary when complete

## Logging

When logging is enabled (`-l` option), the script records:

- Session start/end with timestamps
- Each file processed
- Search queries and results
- User selections
- Successful renames
- Errors and warnings
- Final statistics

**Log format:**
```
================================================================================
Media Renamer Session Started: 2024-01-15 14:30:22
Target Directory: /home/user/media
Dry Run: false
================================================================================
[2024-01-15 14:30:23] [INFO] Processing movie file: The.Matrix.1999.mkv
[2024-01-15 14:30:24] [INFO] User selected: The Matrix (1999)
[2024-01-15 14:30:24] [SUCCESS] Renamed: The.Matrix.1999.mkv -> The Matrix (1999).mkv
```

## Tips

- **Always do a dry run first** (`-d`) to preview changes
- **Back up your files** before batch renaming
- Use logging (`-l`) to keep a record of changes
- If automatic detection fails, you can enter a custom search term
- The script only processes files in the immediate directory (not subdirectories)

## Troubleshooting

### "API Error: Invalid API key"
- Verify your TMDB API key is correct
- Check if the key is properly set via `-k` flag or `TMDB_API_KEY` environment variable

### "No matches found"
- Try entering a custom search term when prompted
- Check if the movie/show title in the filename is spelled correctly
- Some very new or obscure titles may not be in TMDB yet

### "Missing required dependencies"
- Install curl and jq using your package manager (see Requirements section)

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Acknowledgments

- [The Movie Database (TMDB)](https://www.themoviedb.org/) for providing the free API
- All contributors and users of this script
