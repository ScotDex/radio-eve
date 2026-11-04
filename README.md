# Radio EVE

A hands-off, scheduled lofi-style stream for EVE Online players: a seamless in-game scene on loop, EVE music underneath, broadcast to Twitch.

**Watch:** [twitch.tv/scottish_dex](https://twitch.tv/scottish_dex)

---

## How it works

Everything is rendered **once, offline**. The server never encodes video; it just copies pre-built files to Twitch, so it uses almost no CPU.

```
                ┌───────────────────────────── your PC ─────────────────────────────┐
 in-game capture ──► make-loop.ps1 ──► scene_loop.mp4   (1080p, seamless crossfade)
 music tracks   ──► make-mix.ps1  ──► mix.m4a           (loudness-normalised, shuffled)
                └────────────────────────────────┬───────────────────────────────────┘
                                                 │ scp
                ┌──────────────────────────── droplet ──────────────────────────────┐
 stitched.mp4 ─┐
               ├──► ffmpeg (-c copy, both inputs looped) ──RTMP──► Twitch
 mix.m4a ──────┘
                cron starts/stops the container on a schedule
                └────────────────────────────────────────────────────────────────────┘
```

Video and music loop **independently**, so a 2-minute scene over 13+ hours of music almost never repeats the same picture with the same track.

---

## Repo layout

```
radio-eve/
├── docker-compose.yml     # single ffmpeg service
├── .env                   # TWITCH_KEY (never committed)
├── .env.example           # template for .env
├── scripts/
│   ├── make-loop.ps1      # capture → seamless 1080p loop
│   └── make-mix.ps1       # tracks → one normalised mix.m4a
├── radio/stitched.mp4     # current scene (not committed)
├── music/mix.m4a          # current music mix (not committed)
└── scenes/*.mp4           # optional rotation pool (not committed)
```

Media and secrets are excluded by `.gitignore`.

---

## Requirements

**PC (building media)**
- Windows + PowerShell
- ffmpeg/ffprobe: `winget install --id Gyan.FFmpeg -e`
- yt-dlp (optional, for sourcing music): `winget install --id yt-dlp.yt-dlp -e`

**Server**
- Linux host with Docker + Docker Compose
- ~1–2 GB free disk for media

---

## Setup

1. Clone the repo onto the server:
   ```bash
   git clone https://github.com/ScotDex/radio-eve.git
   cd radio-eve
   ```
2. Create `.env` from the template and lock it down:
   ```bash
   cp .env.example .env
   nano .env          # TWITCH_KEY=your-stream-key
   chmod 600 .env
   ```
3. Upload the media from your PC:
   ```powershell
   scp scene_loop.mp4 root@SERVER:~/radio-eve/radio/stitched.mp4
   scp mix.m4a        root@SERVER:~/radio-eve/music/mix.m4a
   ```
4. Start it:
   ```bash
   docker compose up -d
   ```

> **Testing without going live:** append `?bandwidthtest=true` to the RTMP URL in `docker-compose.yml`. Twitch receives the stream but doesn't broadcast it. Check it at [inspector.twitch.tv](https://inspector.twitch.tv).

---

## Building media

### Scenes: `make-loop.ps1`

Record an in-game scene (UI hidden, slow camera, nothing crossing the frame), ideally 2+ minutes. Then:

```powershell
.\scripts\make-loop.ps1 capture.mkv
```

The script reads the clip length, crossfades the last 3 s into the first 3 s so the loop seam is invisible, and renders 1080p60 H.264 (`veryslow`, `tune film`, CRF 16, 6000k cap, 2 s keyframes).

Lighter output (less bandwidth):
```powershell
.\scripts\make-loop.ps1 capture.mkv -Fps 30 -MaxRateK 4500
```

### Music: `make-mix.ps1`

Put source tracks (`.m4a`, `.mp3`, `.flac`) next to the script and run:

```powershell
.\scripts\make-mix.ps1
```

It converts each new track to a normalised 44.1 kHz WAV (cleaning problem filenames automatically), shuffles them, and encodes one `mix.m4a` (AAC 192k). Re-runs only convert new tracks.

To drop a track, move its WAV into `wav\rejects\`; it stays excluded from future runs.

---

## Schedule

Runs during EVE prime time (UTC). Installed with `crontab -e`:

```cron
0 18 * * 3,4     cd /root/radio-eve && docker compose up -d >> cron.log 2>&1
0 12 * * 6,0     cd /root/radio-eve && docker compose up -d >> cron.log 2>&1
0 0  * * 0,1,4,5 cd /root/radio-eve && docker compose down  >> cron.log 2>&1
```

| Day | On air (UTC) |
|---|---|
| Wednesday | 18:00 – 00:00 |
| Thursday | 18:00 – 00:00 |
| Saturday | 12:00 – 00:00 |
| Sunday | 12:00 – 00:00 |

### Optional: scene rotation

Keep several loops in `scenes/` and prefix the start lines with a random pick:

```cron
cd /root/radio-eve && cp "$(ls scenes/*.mp4 | shuf -n1)" radio/stitched.mp4 && docker compose up -d >> cron.log 2>&1
```

---

## Operations

| Task | Command |
|---|---|
| Status | `docker ps` |
| Live logs | `docker compose logs -f` |
| Resource use | `docker stats --no-stream` |
| Cron history | `cat cron.log` |
| Swap scene/music | upload new file, then `docker compose restart` |
| Stop now | `docker compose down` |

### Troubleshooting

- **Stream won't start on schedule:** check `cron.log` and `date` (the server should be on UTC).
- **Glitch at the loop point:** re-render the scene with `make-loop.ps1`; raw captures aren't seamless.
- **Scratchy or uneven audio:** rebuild with `make-mix.ps1`. Never concat raw MP3s with mixed sample rates.
- **High CPU:** something is re-encoding. The ffmpeg command must use `-c copy`.

---

## Credits & licensing

- **Music:** EVE Online soundtrack by CCP Games / [Fenris Creations](https://soundcloud.com/fenriscreations), used with CCP's blessing for community content.
- **Footage:** captured in EVE Online.

EVE Online and the EVE logo are trademarks of CCP hf. This is a fan project and is not affiliated with or endorsed by CCP hf.

The scripts and configuration in this repo are yours to reuse. The music and footage are **not** included and are not covered by any licence here.