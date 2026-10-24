<p align="center"><em>Proudly Made in Nebraska. Go Big Red! 🌽 <a href="https://xkcd.com/2347/">https://xkcd.com/2347/</a></em></p>

# ChoomCheats

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Toggleable single-player cheats for **Cyberpunk 2077 on macOS**, written in pure
[redscript](https://github.com/jac3km4/redscript) so they work on the native Mac
build (GOG and Steam) without re-signing or injecting into the game.

| Cheat | What it does | Default key |
|---|---|---|
| Infinite health | Engine god mode, health refilled every second | F6 |
| Infinite money | Eddies kept at or above 1,000,000 | F7 |
| Invisible | NPCs can't see you | F8 |
| Unlimited carry | +100,000 carry capacity, overweight effect cleared | F10 |

Press a key in-game to switch that cheat on or off; a short on-screen message
confirms the change. On Mac keyboards you may need to hold **fn** for F-keys.
F9 is skipped because it's the game's Quick Load key. The keys work on foot and
in vehicles (anywhere Quick Save works).

## Status

Compiles against the Cyberpunk 2077 **2.5** macOS scripts. **Not yet verified
in-game** — see [BACKLOG.md](BACKLOG.md).

## Requirements

- Cyberpunk 2077 **2.5** for macOS (GOG or Steam), Apple Silicon.
- redscript **0.5.32** (macOS build). The installer sets it up if it's missing.

## Install

Back up your saves first, then:

```sh
git clone https://github.com/CryptoJones/ChoomCheats.git
cd ChoomCheats
scripts/install.sh                      # finds the game, shows the plan, asks first
scripts/install.sh --game "/path/to/Cyberpunk 2077"   # or point at the folder
```

The installer:

1. Installs redscript 0.5.32 into the game folder if it isn't there, checking
   the download's SHA-256 and clearing macOS's quarantine flag on its tools.
2. Copies the mod to `r6/scripts/ChoomCheats`.
3. Adds the four key bindings to `r6/config/inputUserMappings.xml` and
   `inputContexts.xml` inside a marked block. The originals are saved once as
   `*.choomcheats.bak`.
4. Compiles the game scripts, so the game can be started normally from GOG
   Galaxy, Steam or the app.

Change keys with `--key-god`, `--key-money`, `--key-invisible`, `--key-carry`
(for example `--key-carry F11`). Running it again is safe: it replaces its own
block rather than adding another.

**After a game update or a "verify files" in your launcher, run the installer
again** — updates replace the config files and compiled scripts.

## Uninstall

```sh
scripts/uninstall.sh
```

Removes the mod and its key bindings and recompiles the scripts. redscript is
left in place because other mods may use it.

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
