<p align="center"><em>Proudly Made in Nebraska. Go Big Red! 🌽 <a href="https://xkcd.com/2347/">https://xkcd.com/2347/</a></em></p>

# ChoomCheats

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Toggleable single-player cheats for **Cyberpunk 2077 on macOS**, written in pure
[redscript](https://github.com/jac3km4/redscript) so they work on the native Mac
build (GOG and Steam) without re-signing or injecting into the game.

| Cheat | What it does | Default key |
|---|---|---|
| Infinite health | Engine god mode, health refilled every second | F7 |
| Infinite money | Eddies kept at or above 1,000,000 | F8 |
| Invisible | NPCs can't see you | F9 |
| Unlimited carry | +100,000 carry capacity, overweight effect cleared | F10 |

Press a key in-game to switch that cheat on or off; a short on-screen message
confirms the change. On Mac keyboards you may need to hold **fn** for F-keys.

## Status

**Work in progress — not yet verified in-game.** See [BACKLOG.md](BACKLOG.md).

## Requirements

- Cyberpunk 2077 **2.5** for macOS (GOG or Steam).
- redscript **0.5.32** or newer (macOS build). The installer can set it up.

## Settings

Edit the `ChoomConfig` class at the top of
[`src/r6/scripts/ChoomCheats/ChoomCheats.reds`](src/r6/scripts/ChoomCheats/ChoomCheats.reds)
to change the money floor, carry bonus, messages, or which cheats start enabled,
then reinstall.

## Fair use

Single-player only, on your own legally owned copy. Back up your saves first.
Not affiliated with CD PROJEKT RED. No game files are distributed here.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
