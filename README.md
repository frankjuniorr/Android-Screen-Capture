## Android Screen Capture

##### A project inspired and forked from [Outlook](https://github.com/outlook/gifcap)

![OS](https://img.shields.io/badge/OS-Linux-212121.svg?style=true)
![dependence](https://img.shields.io/badge/dependence-adb-F44336.svg?style=true)
![tool](https://img.shields.io/badge/tool-ffmpeg-4CAF50.svg?style=true)
![tool](https://img.shields.io/badge/tool-ffprobe-4CAF50.svg?style=true)

### Description

A shell script to record GIFs from your Android devices

A picture is worth 1,000 words - and, when prototyping animations, recording visual glitches, etc, a video is
worth far more.  This script makes it easy to capture and share subtle app behavior by producing ready-to-paste-in-Slack
GIFs with a single command.

<div align="center">
  <img src="example.gif" alt="An animated GIF showing an Android app opening" />
  <br />
</div>

### Usage

```bash
./screen_capture_gif.sh your_file_name.gif
<CTRL+C to stop recording>
```

Note: you'll need an physical Android device plugged in - emulators don't generally have `screenrecord` built in.

### Install

#### Linux

Ensure `adb`, `ffmpeg`, and `ffprobe` are on your `$PATH`.

#### Suggestion

Copy `screen_capture_gif` and place it somewhere on your `$PATH`.

-------

Copyright © Microsoft Corporation
