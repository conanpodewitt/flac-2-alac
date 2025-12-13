# flac-2-alac

For converting files encoded in the .flac audio codecs to .m4a encoded codecs because apparently Apple refuses to recognise one of them. Optimised for parsing weird MacOS directories and .zsh. Also embeds loose artwork from the source directory into each output file/track.

## Requirements

- `zsh`.
- `ffmpeg` available in `PATH` (Homebrew installation should work on macOS).

## Usage

```bash
./flac-2-alac.sh /path/to/source/album /path/to/output
```

- The **source directory** must contain `.flac` files and optionally a single cover image (`.jpg`, `.jpeg`, `.png`, or `.gif`).
- The **destination directory** is created if missing; existing `.m4a` files with the same basenames are overwritten.
- All tracks are encoded losslessly into ALAC, and if a cover image exists it is embedded into each output file.

## Behavior notes

- The script exits early if no FLAC tracks are found.
- Filenames containing spaces are handled correctly via zsh globbing.
- The script skips macOS resource-fork files (`._*`).
