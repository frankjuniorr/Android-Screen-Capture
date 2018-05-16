## screen_capture_gif

A shell script to record GIFs from your Android devices

A picture is worth 1,000 words - and, when prototyping animations, recording visual glitches, etc, a video is
worth far more.  This script makes it easy to capture and share subtle app behavior by producing ready-to-paste-in-Slack
GIFs with a single command.

<div align="center">
  <img src="example.gif" alt="An animated GIF showing an Android app opening" />
  <br />
  <em>Example output</em>
</div>

### Usage

```bash
./screen_capture_gif.sh your_file_name.gif
<CTRL+C to stop recording>
```

Note: you'll need an physical Android device plugged in - emulators don't generally have `screenrecord` built in.

### Install

#### Linux

Ensure `adb`, `ffmpeg`, and `ffprobe` are on your $PATH.  Also make sure that your console window is
capable of executing `bash`.

Copy `gifcap` and place it somewhere on your $PATH.

-------

Copyright © Microsoft Corporation
