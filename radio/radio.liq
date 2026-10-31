settings.log.stdout := true
music = playlist(mode="randomize", reload_mode="watch", "/music")
music = crossfade(music)
radio = mksafe(music)

nowplaying = ref("")
radio.on_metadata(synchronous=true, fun (m) -> nowplaying := m["title"])

# output.harbor(%mp3(bitrate=128), port=8000, mount="radio", radio)

key = environment.get("TWITCH_KEY")
tw_url = "rtmp://live.twitch.tv/app/#{key}"

bg = single("/radio/loop.mp4")

bg = video.add_text(
  x=40, y=640,
  size=32,
  color=0xFFFFFF,
  font="/radio/font.ttf",
  speed=0,
  {nowplaying()},
  bg
)

stream = mksafe(source.mux.video(video=bg, radio))

output.url(
  url=tw_url,
  %ffmpeg(
    format="flv",
    %audio(codec="aac", b="128k"),
    %video(codec="libx264", preset="superfast", g=50, b="2500k")
  ),
  stream
)