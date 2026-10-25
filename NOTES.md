# ChocolateQuake for MiSTer: notes

How the port works and how it is built. For playing it, see the [README](README.md).

## How the port works

The game is [Chocolate Quake](https://github.com/Henrique194/chocolate-quake) with a `MISTER_HYBRID` build option; what is the MiSTer's own is in `chocolatequake/src/mister/` and in the places marked `MISTER_HYBRID`.

- **Video** (`src/video/src/vid_mister.c`, in place of the PC's window and mode code): the game draws into the window surface of SDL's "mister" driver in 8 bits, the palette done by the core, as DOS Quake drew into the VGA's memory. Those pixels are the library's two frame buffers in turn (`SDL_MISTER_DIRECT`), so the frame reaches the core without a copy, with two pages as Quake had with a VGA's page flipping. The OSD's *Resolution* is read every frame and changes the mode at once. In the 640-wide modes the 3D view has twice the detail and the 2D (status bar, console, menus) is laid out in 320 pixels and drawn twice as wide (`Draw_WideBlock()` in `draw.c`).
- **Renderer**: Chocolate Quake's C, made faster for the MiSTer's Cortex-A9 with the same pictures as id's code (every frame of `timedemo demo1` compared, pixels and z buffer). The span drawers keep their state in registers and never divide an integer per pixel (the CPU has no divider), the z spans use NEON, and `d_spanjob.c` draws the textured world surfaces and the models' spans on both CPUs, the worker on CPU1.
- **240 lines**: the view fills the screen, the status bar is drawn over it every frame at the bottom HUD margin, the console's notify lines, the chat line and the network icons at the top one. Menus keep Quake's layout from the top of the screen.
- **Input**: the MiSTer joystick is an SDL game controller (`IN_AddMiSTerMappings()` in `in_gamepad.c`); the core's buttons are bound as Quake keys after `default.cfg` (`MiSTer_PadBindings()`), so a player's `config.cfg` and *Customize controls* change them as on the PC. In menus *Menu OK* / *Menu Back* are Enter and Esc and the game's buttons do nothing, except while *Customize controls* waits for one.
- **Cheats** (`Host_MiSTerCheats()` in `host_cmd.c`): the switches run Quake's `god`, `noclip` and `notarget` on the local server whenever the player's state differs from the OSD, again on every level; the triggers are `impulse 9`, `impulse 255`, health and armor set directly, and the level's exit (the `trigger_changelevel` whose map comes first by name, so never the secret one).
- **Rumble** (`MiSTer_Rumble*()` in `mister_port.c`): hits from the damage the server reports, shots from how far the weapon kicks the view, hard landings from their sounds, explosions by their distance.
- **Music**: Chocolate Quake plays the CD's tracks from `music/trackNN.*`. The MiSTer has no libvorbis, libFLAC or libmad, so `snd_mister.c` decodes with the single-file decoders of SDL2_mixer's source (stb_vorbis, dr_flac, minimp3).
- **Game data**: `MiSTer_SelectGame()` picks the game (`MH_PickGame()`) and adds `-basedir .` and `-hipnotic` / `-rogue`; folder, pak and file names are found in any case (`COM_FindCase()` and `COM_FindPathCase()` in `com_fs.c`), since CD copies have `ID1/PAK0.PAK` and music may come as `MUSIC/TRACK02.OGG`.

### Frame pacing

The game is drawn a field ahead (`DRAW_AHEAD` 1 in `mister_port.c`). With Chocolate Quake's renderer as it came, the 640x240 view took about 16 ms on the ARM, most of a field, and the slower frames missed their field: in demo1, 50 seconds at 640x240 (`MISTER_HYBRID_PACE=1`, two runs each), without drawing ahead about 200 frames were never shown and 525 shown twice, with it about 38 and 368. With the faster renderer the 3D view takes about 9 ms, and the same run with drawing ahead has 2 frames never shown and 2 shown twice. Whether drawing ahead is still worth its field of latency has not been measured again. `MISTER_HYBRID_FPSLOG=1` prints where a frame's time goes.

## Building

Everything builds in Docker on a Linux PC.

```sh
git clone --recursive https://github.com/ItsDanik/ChocolateQuake_MiSTer.git
cd ChocolateQuake_MiSTer
./build.sh              # ARM game binary  -> build/mister/chocolatequake
./core/build_core.sh    # FPGA core (Quartus Lite 17.0.2) -> core/output_files/ChocolateQuake.rbf
./package.sh            # release zip      -> dist/ChocolateQuake_YYYYMMDD.zip
```

The toolchain image (Debian bullseye, glibc 2.31 to match the MiSTer) is built from `hybrid/toolchain/` on first use. The first build also downloads and builds SDL2, SDL2_mixer and SDL2_net.

### Repository layout

| Path | |
|---|---|
| `hybrid/` | submodule: [ItsDanik/Hybrid_MiSTer](https://github.com/ItsDanik/Hybrid_MiSTer), what all our hybrid ports share: the FPGA host module, the ARM side library, SDL2 drivers, the launcher (`danik_hybrid_ports.sh`), toolchain and conventions. See its README. |
| `core/` | FPGA core, based on [Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer): `ChocolateQuake.sv` (OSD and button names) around `hybrid/rtl/hybrid_host.sv` |
| `chocolatequake/` | submodule: the game, branch `mister`, with the MiSTer changes |
| `package/` | files shipped in the release next to the binary (`danik_hybrid_launch.sh`, README), and `games.txt`: the games and their menu entries |
| `releases/` | release packages |

### Development notes

- `./build.sh host` builds the same game for the PC. It runs against `hybrid/tools/fakecore`, a stand-in for the FPGA core that takes scripted input and saves screenshots and audio:
  ```sh
  gcc -O2 -o build/host/fakecore hybrid/tools/fakecore.c
  build/host/fakecore /tmp/shm script.txt audio.raw &
  cd <data folder> && MISTER_HYBRID_SHM=/tmp/shm <repository>/build/host/chocolatequake
  ```
- `MISTER=root@<address> tools/test_on_mister.sh <id>` tries the build on a MiSTer next to what is installed there, without installing it: from `/tmp`, with the installed game's folder mirrored there (what the game writes stays in `/tmp`) and its own OSD settings. `list` and `nodata` for the core started by itself and without data, `log` for the game's log, `stop` to remove all of it again.
- On the MiSTer, `MISTER_HYBRID_SPANTHREAD=0` draws on one CPU, `MISTER_HYBRID_DIRECT=0` copies the frame instead of drawing into the library's buffers, `MISTER_HYBRID_FRAMEHASH=1` prints a hash of every frame (with `+timedemo demo1`, to show a change to the renderer draws the same pictures), `MISTER_HYBRID_PROFILE=<file>` samples where the game's time goes into that file and `MISTER_HYBRID_ARGS` adds command line options.
- `touch /tmp/chocolatequake_nolaunch` on the MiSTer keeps the core loaded without starting the game, so you can start a development binary by hand (set `MISTER_HYBRID_CORE=ChocolateQuake`, and `MISTER_HYBRID_SET` for a game's set name). `/tmp/danik_hybrid_ports.log` shows what the launcher daemon did.
