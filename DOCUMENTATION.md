# Media Renamer - Documentation

Detailed documentation for the file renamer script.

## Table of Contents

- [Filename Patterns](#filename-patterns)
- [Stripped Indicators](#stripped-indicators)
- [Interactive Workflow](#interactive-workflow)
- [Logging](#logging)
- [Tips](#tips)
- [Troubleshooting](#troubleshooting)

## Filename Patterns

### TV Shows

The script recognizes these patterns and extracts season/episode info:

| Pattern | Example |
|---------|---------|
| `S01E02` | `Breaking.Bad.S01E02.720p.BluRay.mkv` |
| `1x02` | `Breaking.Bad.1x02.HDTV.mkv` |
| `Season.1.Episode.2` | `Breaking Bad Season 1 Episode 2.mkv` |

**Output:** `Breaking Bad - S01E02 - Cat's in the Bag....mkv`

### Movies

Any video file without TV show patterns is treated as a movie.

| Input | Output |
|-------|--------|
| `The.Matrix.1999.BluRay.1080p.x264.mkv` | `The Matrix (1999).mkv` |
| `Inception.2010.REMASTERED.720p.mkv` | `Inception (2010).mkv` |

## Stripped Indicators

The script automatically removes these from filenames before searching TMDB:

| Category | Examples |
|----------|----------|
| **Quality** | 720p, 1080p, 2160p, 4K, UHD, HDR |
| **Source** | BluRay, BRRip, DVDRip, WebRip, Web-DL, HDTV |
| **Codec** | x264, x265, H.264, H.265, HEVC, XviD, DivX |
| **Audio** | AAC, AC3, DTS, 5.1, 7.1 |
| **Release** | Proper, Repack, Extended, Unrated, Remastered |
| **Groups** | YIFY, YTS, RARBG, EZTV, and many others |

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

Enable logging with `-l filename.log`. The log records:

- Session start/end with timestamps
- Each file processed
- Search queries and results
- User selections
- Successful renames
- Errors and warnings

**Example log output:**
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
- Install curl and jq:
  ```bash
  # Debian/Ubuntu
  sudo apt install curl jq

  # macOS
  brew install curl jq

  # Fedora/RHEL
  sudo dnf install curl jq
  ```
