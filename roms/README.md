# ROMs

Copy both files to `/media/fat/games/Lynx/` on the MiSTer SD card. The core
loads them on its own when it starts.

| File | Size | Machine | Contents (8K pages) |
|---|---|---|---|
| `boot.rom`  | 64K | Lynx 48K / 96K / 96K Scorpion | 0: 48K-1, 1: 48K-2, 2: 96K-1, 3: 96K-2, 4: 96K-3, 5: 96K-3 Scorpion, 6: XDOS, 7: empty |
| `boot1.rom` | 32K | Lynx 128K | 0: 128K-1, 1: 128K-2, 2: 128K-3, 3: XDOS |

The page order is the one used by Kyp's Poseidon cores (`romP` in `psd.v`).

`src/` holds the individual ROMs, with their MAME names (sets `lynx48k`,
`lynx96k` and `lynx128k`), and `python3 tools/make_roms.py` rebuilds both
files from them. ROMs smaller than 8K are padded with 0xFF, as MAME does.

| File | SHA1 | Page |
|---|---|---|
| `lynx48-1.ic46` | 7ded5184561168e159a30fa8e9d3fde5e52aa91a | 48K-1 |
| `lynx48-2.ic45` | c08a78ecb4eb05baa4c52488fce3648cd2688744 | 48K-2 |
| `lynx9646.ic46` | 77a4af7557382003d697d08f364839e2dc28f063 | 96K-1 |
| `lynx9645.ic45` | 3fca46bd68422d34c6cd801dd904507e52bd8846 | 96K-2 |
| `lynx9644.ic44` | c372a8d26399b9b45e615b674d61ccda76491b8b | 96K-3 (4K) |
| `skorprom.ic44` | c707bdcecef79774c2a8a23d1f3e9ba382cb9304 | 96K-3 Scorpion (v2.1, Reading Lynx User Group) |
| `dosrom.rom`    | e77f0ca99790551a7122945f3194516b2390fb69 | XDOS (disk ROM, started with `XROM`) |
| `lynx128-1.ic1` | 36567c2fbd9cf72f758e8cb80c21cb4d82040752 | 128K-1 |
| `lynx128-2.ic2` | e12a7ebea3fae5eb375c03e848dbb81070d9d189 | 128K-2 |
| `lynx128-3.ic3` | 1092367b2af51c72ce9be367179240d692aeb131 | 128K-3 |

| Result | SHA1 |
|---|---|
| `boot.rom`  | a40da1b4c09dcd73c2732d31b2ade41dec88f3a9 |
| `boot1.rom` | 79a3a77f8ffcecfb6c6cfb6511e9fbc5fe641c38 |
