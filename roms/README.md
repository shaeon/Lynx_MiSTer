# ROMs

Copy both files to `/media/fat/games/Lynx/` on the MiSTer SD card. The core
loads them on its own when it starts.

| File | Size | Machine | Contents (8K pages) |
|---|---|---|---|
| `boot.rom`  | 64K | Lynx 48K / 96K / 96K Scorpion | 0: 48K-1, 1: 48K-2, 2: 96K-1, 3: 96K-2, 4: 96K-3, 5: 96K-3 Scorpion, 6: XDOS, 7: empty |
| `boot1.rom` | 32K | Lynx 128K | 0: 128K-1, 1: 128K-2, 2: 128K-3, 3: XDOS |

The page order is the one used by Kyp's Poseidon cores (`romP` in `psd.v`).

`src/` holds the individual ROMs, and `python3 tools/make_roms.py` rebuilds
both files from them:

| File | SHA1 | Notes |
|---|---|---|
| `lynx48-1.rom` | 7ded5184561168e159a30fa8e9d3fde5e52aa91a | MAME `lynx48-1.ic46` |
| `lynx48-2.rom` | c08a78ecb4eb05baa4c52488fce3648cd2688744 | MAME `lynx48-2.ic45` |
| `lynx96-1.rom` | 7ded5184561168e159a30fa8e9d3fde5e52aa91a | same as 48K-1 |
| `lynx96-2.rom` | c08a78ecb4eb05baa4c52488fce3648cd2688744 | same as 48K-2 |
| `lynx96-3.rom` | f86a729b01de286197c550974f7825c12815a4f4 | third ROM of the 96K |
| `lynx96-3-scorpion.rom` | c707bdcecef79774c2a8a23d1f3e9ba382cb9304 | MAME `skorprom.ic44` (Scorpion v2.1) |
| `lynx128-1.rom` | 36567c2fbd9cf72f758e8cb80c21cb4d82040752 | MAME `lynx128-1.ic1` |
| `lynx128-2.rom` | e12a7ebea3fae5eb375c03e848dbb81070d9d189 | MAME `lynx128-2.ic2` |
| `lynx128-3.rom` | 1092367b2af51c72ce9be367179240d692aeb131 | MAME `lynx128-3.ic3` |

The 48K, 96K and 128K ROMs are the same ones used by the
[Lynx48_MiSTer](https://github.com/MiSTer-devel/Lynx48_MiSTer) core.

**Disk ROM (XDOS)**: the disk ROM (`dosrom.rom`, the one started with `XROM`,
MAME SHA1 e77f0ca99790551a7122945f3194516b2390fb69) is not included yet, so
the XDOS page is filled with 0xFF and the disk drive cannot be used. To add it,
copy it to `src/dosrom.rom` and run `python3 tools/make_roms.py`.
