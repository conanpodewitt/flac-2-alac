# flac-2-alac

For converting files encoded in the .flac audio codecs to .m4a encoded codecs because apparently Apple refuses to recognise one of them. Optimised for parsing weird MacOS directories and .zsh. Also embeds loose artwork from the source directory into each output file/track.

## Requirements

- `zsh`.
- `ffmpeg` and `ffprobe` available in `PATH` (Homebrew installation should work on macOS).

## Usage

```bash
./flac-2-alac.sh /path/to/source/album /path/to/destination [--reorg] [--album 'Album Name'] [--year 'Year'] [--genre 'Genre']
```

### Default Mode (no flags)
Converts FLAC files to ALAC with embedded cover art, organized into Artist/Album folder structure:

```bash
./flac-2-alac.sh /path/to/source /path/to/destination
```

- Automatically detects and uses `cover.jpg` from the source directory if present
- Otherwise uses any embedded cover from the FLAC files
- Output: `destination/Artist/Album/01 Track Title.m4a`, `02 Track Title.m4a`, etc.
- All metadata (artist, album, title, track number) is preserved from FLAC tags

### With Custom Metadata
Override metadata extracted from FLAC tags:

```bash
./flac-2-alac.sh /path/to/source /path/to/destination --album 'My Album' --year '2024' --genre 'Rock'
```

- `--album`: Override the album name (also reflected in directory structure)
- `--year`: Override the year/date metadata
- `--genre`: Override the genre metadata
- Works with both default and `--reorg` modes
- Flags can be in any order

### Reorganize Mode (`--reorg`)
Organizes FLAC files into Artist/Album structure, strips embedded artwork, and extracts covers:

```bash
./flac-2-alac.sh /path/to/source /path/to/destination --reorg
./flac-2-alac.sh /path/to/source /path/to/destination --reorg --album 'Custom Album' --year '2025' --genre 'Pop'
```

- Copies FLAC files into the Artist/Album folder structure
- **Removes embedded artwork** from each FLAC file using lossless audio copy (audio is untouched)
- Updates metadata tags (album, year, genre) if custom values provided
- Extracts artwork and saves as `cover.jpg` in each album directory, OR copies any loose cover file from the source
- Output: `destination/Artist/Album/01 Track Title.flac` (clean, no embedded art), plus `cover.jpg` in the album folder
- Useful for organizing and cleaning up artwork from FLAC files without re-encoding audio

## Folder Structure

### Default Mode Output
```
destination/
├── Artist Name/
│   └── Album Name/
│       ├── 01 Track Title.m4a
│       ├── 02 Another Track.m4a
│       └── ...
```

### --reorg Mode Output
```
destination/
├── Artist Name/
│   └── Album Name/
│       ├── 01 Track Title.flac
│       ├── 02 Another Track.flac
│       ├── ...
│       └── cover.jpg
```

## Behavior notes

- The script exits early if no FLAC tracks are found.
- Filenames containing spaces are handled correctly via zsh globbing.
- The script skips macOS resource-fork files (`._*`).
- Metadata tags (artist, album, title, track) are extracted from FLAC files using `ffprobe`. If a tag is missing, sensible defaults are used.
- **Filename sanitization**: Problematic characters in metadata (e.g., `/`, `\`, `:`, `"`, `'`, `*`, `?`, `|`, `<`, `>`) are replaced with underscores to prevent filesystem issues.
- **Long filenames**: Very long filenames are truncated to 200 characters to stay within filesystem limits.
- **Multiple covers**: If multiple image files exist in the source directory, the first one found is used.
- **Metadata overrides**: Use `--album`, `--year`, and `--genre` to override values extracted from FLAC metadata.
  - These are applied to the output files (ALAC or reorganized FLAC)
  - `--album` also affects the directory structure
- **Error handling**: If any file conversion fails, the script stops immediately and removes the entire output directory.
- **Default mode**: If `cover.jpg` exists in the source directory, it is used for all tracks. Otherwise, embedded covers from FLAC files are used.
- **`--reorg` mode**: Strips all embedded artwork from FLAC files (audio remains untouched). Extracts artwork as `cover.jpg` in each album directory, or copies any loose cover file from the source.
