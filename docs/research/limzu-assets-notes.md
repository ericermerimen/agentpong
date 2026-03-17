# LimeZu Asset Packs Notes

Research from 2026-03-15.

## Packs needed for office scene

### Modern Interiors ($1.50)
- URL: https://limezu.itch.io/moderninteriors
- 40+ room themes including offices, control rooms
- Character generator: 100+ outfits, 200 hairstyles, 9 skin colors
- Sizes: 16x16, 32x32, 48x48
- Format: PNG sprite sheets + individual sprites
- License (paid): CC-BY 4.0 -- commercial OK, attribution required, no redistribution

### Modern Office ($2.50)
- URL: https://limezu.itch.io/modernoffice
- Dedicated office furniture: desks, chairs, computers, plants, lamps
- 300+ individual sprites
- Sizes: 16x16, 32x32, 48x48
- No characters included (use Modern Interiors for those)
- License: Same as Modern Interiors

### Free version (testing only)
- Modern_Interiors_Free_v2.2.zip (1MB)
- Living room + classroom furniture only
- 4 characters (Adam, Alex, Amelia, Bob) with idle, sit, run, phone animations
- NON-COMMERCIAL -- fine for prototyping, can't ship
- Characters are 16x16 base, scale 2x to match 32x32 tiles

## License concerns for open source
- Paid license: "CAN'T resell or distribute"
- But LimeZu confirmed CC-BY 4.0 which allows redistribution with attribution
- Tension between itch.io page text and CC-BY 4.0
- Safe approach: don't check assets into public repo, download at build time

## Lessons from mockup attempts
- Free pack has bright RPG colors -- wrong palette for dark dev tool theme
- Tiling 32x32 assets in small spaces (340px wide) looks like a Lego house
- Star-Office-UI works because they use ONE pre-rendered background, not tiles
- LimeZu characters are good quality but need the right context (proper background, matching scale)
