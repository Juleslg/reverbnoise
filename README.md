# reverb_noise

A live audio processor for norns that combines reverb and white noise.

## Installation

1. SSH into your norns and enter the following commands:
```
cd ~/dust/code
git clone https://github.com/yourusername/reverb_noise.git
```

Or install via maiden:
`;install https://github.com/yourusername/reverb_noise`

2. Restart your norns

## Usage

- E1: Main volume
- E2: Noise level
- E3: Reverb mix
- K2 + E2: Reverb time
- K2 + E3: Reverb size
- K3 + E2: Reverb damp
- K3 + E3: Mod depth

## Requirements

- norns (version 221212 or later)
- audio input

## Notes

The script will automatically fall back to FreeVerb if JPverb is not available on your system.

## License

MIT 