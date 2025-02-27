# Jetslalom (Odin Remake)

This repo contains a remake of an old web game called 'Jet slalom'. The goal of the game is to avoid obstacles as long as possible, through increasingly difficult stages.


<p align="center">
  <img src=".readme_assets/demo_anim.gif">
</p>

This was made to experiment with and learn the [Odin programming language](https://odin-lang.org/). If you'd like to alter the game, most of the logic is in the [main.odin](https://github.com/heyoeyo/jetslalom_odin/blob/main/src/main.odin) file. The sequence of stages (and how each stage is configured) can be found in the [stage_def.odin](https://github.com/heyoeyo/jetslalom_odin/blob/main/src/stage_def.odin) file.

## How to play

### Download

Pre-built (x86) executables are available for Linux & Windows on the [releases page](https://github.com/heyoeyo/jetslalom_odin/releases/tag/v1.0).

### Compile

Building/compiling the game requires downloading and [installing Odin](https://odin-lang.org/docs/install/). For reference, I used the [dev-2025-01](https://github.com/odin-lang/Odin/releases/tag/dev-2025-01) release from the odinlang github page (pretty painless).

With Odin installed, simply type the following command (in terminal) from the root folder of the repo:
```bash
odin run src
```
And that's it! This command will compile and immediately run the game.