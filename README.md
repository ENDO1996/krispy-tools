# Krispy Tools for DaVinci Resolve

[![Smoke test (macOS + Windows)](https://github.com/ENDO1996/krispy-tools/actions/workflows/smoke.yml/badge.svg)](https://github.com/ENDO1996/krispy-tools/actions/workflows/smoke.yml)

Free, open-source tools that take the repetitive parts out of editing in **DaVinci Resolve Studio**: subtitles and captions in every language, finding changes between two versions, rendering marker ranges, batch timeline jobs and more.

Every tool also has its own page with the demo and screenshots at **[resolve.krispytools.com](https://resolve.krispytools.com)**.


Made by Kristaps Prūsis, a video editor in Latvia, for his own work, and shared because they might save you time too.

## All tools at a glance

Click a name for its section further down, with a demo video, what it does and the download.

### Bundles

5 tools in 1: one window with 5 pages instead of 5 separate tools to install and open. Each tool inside is also available on its own.

| Tool | What it does | Demo | Download |
|---|---|---|---|
| [Resolve Automator (5 tools in 1)](#resolve-automator-5-tools-in-1) | Timeline Renamer, Marker Screenshots, Marker Insert, Track Overlay and Batch Export in one window. | [Video](https://resolve.krispytools.com/tools/resolve-automator/) | [`Resolve Automator.lua`](tools/Bundles/Resolve%20Automator.lua) |
| [Resolve Text Toolkit (5 tools in 1)](#resolve-text-toolkit-5-tools-in-1) | Caption Titler, SRT Replacer, Font Changer, Template Duplicator and Subtitle Creator in one window. | [Video](https://resolve.krispytools.com/tools/resolve-text-toolkit/) | [`Resolve Text Toolkit.lua`](tools/Bundles/Resolve%20Text%20Toolkit.lua) |

### Text

| Tool | What it does | Demo | Download |
|---|---|---|---|
| [Caption Titler](#caption-titler) | Build styled, animated Text+ captions from subtitles using your own title template. | [YouTube](https://youtu.be/AJtufTwBprc) | [`Caption Titler.lua`](tools/Text/Caption%20Titler.lua) |
| [Font Changer](#font-changer) | Change the font on every Text+ clip in one click. | [YouTube](https://youtu.be/njY6Przz3rk) | [`Font Changer.lua`](tools/Text/Font%20Changer.lua) |
| [SRT Replacer](#srt-replacer) | Swap your captions to another language from an SRT, keeping style and timing. | [YouTube](https://youtu.be/G_YipSFSRSs) | [`SRT Replacer.lua`](tools/Text/SRT%20Replacer.lua) |
| [Subtitle Creator](#subtitle-creator) | Turn Text+ clips into a real Resolve subtitle track and an SRT file. | [YouTube](https://youtu.be/zyH0rNLEiVQ) | [`Subtitle Creator.lua`](tools/Text/Subtitle%20Creator.lua) |
| [Template Duplicator](#template-duplicator) | Move every caption onto another title template, keeping text and timing. | [YouTube](https://youtu.be/NIXifq0zRBc) | [`Template Duplicator.lua`](tools/Text/Template%20Duplicator.lua) |

### Automation

| Tool | What it does | Demo | Download |
|---|---|---|---|
| [Comments to Resolve Markers](#comments-to-resolve-markers) | Paste review notes from anywhere and turn them into Resolve timeline markers. | [YouTube](https://youtu.be/rFFb3p3x3r8) | [`Comments to Resolve Markers.lua`](tools/Utilities/Comments%20to%20Resolve%20Markers.lua) |
| [Batch Export](#batch-export) | Queue many timelines for render with one preset and one output folder. | [YouTube](https://youtu.be/164dyAUp2Qg) | [`Batch Export.lua`](tools/Automation/Batch%20Export.lua) |
| [Marker Insert](#marker-insert) | Drop the same clip at every marker: a whoosh, a title, a graphic or a video. | [Video](https://resolve.krispytools.com/tools/marker-insert/) | [`Marker Insert.lua`](tools/Automation/Marker%20Insert.lua) |
| [Marker Range Render Queue](#marker-range-render-queue) | Turn timeline marker ranges into named Deliver-page render jobs. | [YouTube](https://youtu.be/Y5H6EdyOCh4) | [`Marker Range Render Queue.lua`](tools/Automation/Marker%20Range%20Render%20Queue.lua) |
| [Marker Screenshots](#marker-screenshots) | Save a still at every marker of one colour, named after the marker. | [Video](https://resolve.krispytools.com/tools/marker-screenshots/) | [`Marker Screenshots.lua`](tools/Automation/Marker%20Screenshots.lua) |
| [Timeline Renamer](#timeline-renamer) | Duplicate or rename many Resolve timelines at once with find and replace. | [YouTube](https://youtu.be/2HFc1IR6s3k) | [`Timeline Renamer.lua`](tools/Automation/Timeline%20Renamer.lua) |
| [Track Overlay](#track-overlay) | Cover every clip on a track with a template clip, cut for cut. | [Video](https://resolve.krispytools.com/tools/track-overlay/) | [`Track Overlay.lua`](tools/Automation/Track%20Overlay.lua) |
| [Video Difference Marker](#video-difference-marker) | Compare two video versions and add Resolve markers where visual changes occur. | [Video](https://resolve.krispytools.com/tools/video-difference-marker/) | [`Video Difference Marker.lua`](tools/Automation/Video%20Difference%20Marker.lua) |

### Utilities

| Tool | What it does | Demo | Download |
|---|---|---|---|
| [Resolve Page Time Tracker](#resolve-page-time-tracker) | Track active editing time by Resolve page, session, and project. | [Video](https://resolve.krispytools.com/tools/resolve-page-time-tracker/) | [`Resolve Page Time Tracker.lua`](tools/Utilities/Resolve%20Page%20Time%20Tracker.lua) |
| [YouTube Chapter Exporter](#youtube-chapter-exporter) | Turn Resolve timeline markers into a ready-to-paste YouTube chapter list. | [YouTube](https://youtu.be/TniY1OCkV7o) | [`YouTube Chapter Exporter.lua`](tools/Utilities/YouTube%20Chapter%20Exporter.lua) |

## Tool by tool

---

### Resolve Text Toolkit (5 tools in 1)

**Bundles** · 5 tools in 1: Caption Titler, SRT Replacer, Font Changer, Template Duplicator and Subtitle Creator in one window with 5 pages.

https://github.com/user-attachments/assets/5c86c193-3c74-4a0d-92f3-e1fbf44b0fda

- Subtitle Creator turns rough Text+ clips into a real subtitle track and an SRT for YouTube.
- Caption Titler builds styled Text+ captions from subtitles using your own Fusion template, one clip per line.
- SRT Replacer swaps a translated SRT into the same caption clips, keeping style and timing.
- Font Changer switches every caption to another font in one go, for languages like Japanese.
- Template Duplicator moves every caption onto a new template without retyping.

[▶ Watch the demo](https://resolve.krispytools.com/tools/resolve-text-toolkit/) · [⬇ Download Resolve Text Toolkit.lua](tools/Bundles/Resolve%20Text%20Toolkit.lua) · [Tool page](https://resolve.krispytools.com/tools/resolve-text-toolkit/)

---

### Resolve Automator (5 tools in 1)

**Bundles** · 5 tools in 1: Timeline Renamer, Marker Screenshots, Marker Insert, Track Overlay and Batch Export in one window with 5 pages.

https://github.com/user-attachments/assets/e76b0a9a-35ee-4c41-a6fe-591787c5e7f4

- Timeline Renamer: duplicate or rename many timelines with find and replace.
- Marker Screenshots: export a still at every marker, named after the marker.
- Marker Insert: drop a whoosh, title, graphic or video at every marker on its own track.
- Track Overlay: put an adjustment clip, graphic or sound over every shot, cut for cut.
- Batch Export: queue many timelines with one render preset.

[▶ Watch the demo](https://resolve.krispytools.com/tools/resolve-automator/) · [⬇ Download Resolve Automator.lua](tools/Bundles/Resolve%20Automator.lua) · [Tool page](https://resolve.krispytools.com/tools/resolve-automator/)

---

### Caption Titler

**Text** · Build styled, animated Text+ captions from subtitles using your own title template.

https://github.com/user-attachments/assets/1ea761b1-b398-48e4-9a87-5b7c1c134d08

- Styled, animated captions for social, from any subtitle file.
- Uses your own Fusion title template, so every caption matches your look.
- One Text+ clip per line, timed to the frame.

[▶ Watch the demo](https://youtu.be/AJtufTwBprc) · [⬇ Download Caption Titler.lua](tools/Text/Caption%20Titler.lua) · [Tool page](https://resolve.krispytools.com/tools/caption-titler/)

---

### SRT Replacer

**Text** · Swap your captions to another language from an SRT, keeping style and timing.

https://github.com/user-attachments/assets/1441e525-e0ff-4025-be3c-16865cf42dfa

- A German, Spanish or Japanese version without retyping a caption.
- Style, animation and timing stay as they are; only the words change.
- Dry Run shows exactly how many clips will change first.

[▶ Watch the demo](https://youtu.be/G_YipSFSRSs) · [⬇ Download SRT Replacer.lua](tools/Text/SRT%20Replacer.lua) · [Tool page](https://resolve.krispytools.com/tools/srt-replacer/)

---

### Font Changer

**Text** · Change the font on every Text+ clip in one click.

https://github.com/user-attachments/assets/67083541-0c32-45df-88d7-3cc5f650909e

- Every caption to a new font in one click.
- Fixes the empty boxes you get when a Latin font meets Japanese text.
- Change only the clips that match an SRT, if you need to.

[▶ Watch the demo](https://youtu.be/njY6Przz3rk) · [⬇ Download Font Changer.lua](tools/Text/Font%20Changer.lua) · [Tool page](https://resolve.krispytools.com/tools/font-changer/)

---

### Template Duplicator

**Text** · Move every caption onto another title template, keeping text and timing.

https://github.com/user-attachments/assets/360b72e1-85be-4131-87f2-1e9ccd67f7e8

- A new look for every caption without retyping or retiming anything.
- Original clips stay as they are, the new ones go on tracks above.
- Works with any Fusion title template in your Media Pool.

[▶ Watch the demo](https://youtu.be/NIXifq0zRBc) · [⬇ Download Template Duplicator.lua](tools/Text/Template%20Duplicator.lua) · [Tool page](https://resolve.krispytools.com/tools/template-duplicator/)

---

### Subtitle Creator

**Text** · Turn Text+ clips into a real Resolve subtitle track and an SRT file.

https://github.com/user-attachments/assets/d9e14e79-9901-4c4d-9dde-2ab2f2349a95

- Turns the Text+ clips you already typed into a real subtitle track.
- Saves an SRT file for YouTube, Vimeo or a client.
- Timing is taken from the clips, frame accurate.

[▶ Watch the demo](https://youtu.be/zyH0rNLEiVQ) · [⬇ Download Subtitle Creator.lua](tools/Text/Subtitle%20Creator.lua) · [Tool page](https://resolve.krispytools.com/tools/subtitle-creator/)

---

### Video Difference Marker

**Automation** · Compare two video versions and add Resolve markers where visual changes occur.

https://github.com/user-attachments/assets/2f715fb4-0b7a-4ce4-88bf-5ea9cf542261

- Stack two versions of a cut and get a marker on every visual change.
- Finds swapped shots, regrades, added text and logos; identical stretches get no marker.
- Two-pass scan: a fast pass finds changed ranges, a frame-accurate pass places the markers.

[▶ Watch the demo](https://resolve.krispytools.com/tools/video-difference-marker/) · [⬇ Download Video Difference Marker.lua](tools/Automation/Video%20Difference%20Marker.lua) · [Tool page](https://resolve.krispytools.com/tools/video-difference-marker/)

---

### Marker Range Render Queue

**Automation** · Turn timeline marker ranges into named Deliver-page render jobs.

https://github.com/user-attachments/assets/65995873-4978-4d7f-b3ce-cade7425c5fb

- Every duration marker becomes its own render job, named after the marker.
- Filter by marker colour, keep your render preset and output folder.
- Re-run after a revision instead of setting In/Out and file names by hand.

[▶ Watch the demo](https://youtu.be/Y5H6EdyOCh4) · [⬇ Download Marker Range Render Queue.lua](tools/Automation/Marker%20Range%20Render%20Queue.lua) · [Tool page](https://resolve.krispytools.com/tools/marker-range-render-queue/)

---

### Comments to Resolve Markers

**Automation** · Paste review notes from anywhere and turn them into Resolve timeline markers.

https://github.com/user-attachments/assets/6b9ede4a-9cd4-4594-b4ef-3e06f609e919

- Paste notes from email, docs, YouTube, Frame.io or a CSV and get one marker per note.
- Understands 0:39, [0:39], 00:00:39:12, 1m20s, ranges and comments that wrap onto the next line.
- Preview exactly where each note lands before adding.

[▶ Watch the demo](https://youtu.be/rFFb3p3x3r8) · [⬇ Download Comments to Resolve Markers.lua](tools/Utilities/Comments%20to%20Resolve%20Markers.lua) · [Tool page](https://resolve.krispytools.com/tools/comments-to-resolve-markers/)

---

### Batch Export

**Automation** · Queue many timelines for render with one preset and one output folder.

https://github.com/user-attachments/assets/64bb0a02-86c3-4227-b812-c886ed9c5248

- Queue dozens of timelines in one click.
- Uses your own saved render preset, so the settings are always right.
- Each file is named after its timeline.

[▶ Watch the demo](https://youtu.be/164dyAUp2Qg) · [⬇ Download Batch Export.lua](tools/Automation/Batch%20Export.lua) · [Tool page](https://resolve.krispytools.com/tools/batch-export/)

---

### Timeline Renamer

**Automation** · Duplicate or rename many Resolve timelines at once with find and replace.

https://github.com/user-attachments/assets/6dde8b88-d98b-4814-ab84-f4ef28a285c6

- Find and replace in the names of many timelines at once.
- Duplicate mode makes one copy per entry: v2, Client Review, 9x16, Final.
- Preview every new name before anything changes.

[▶ Watch the demo](https://youtu.be/2HFc1IR6s3k) · [⬇ Download Timeline Renamer.lua](tools/Automation/Timeline%20Renamer.lua) · [Tool page](https://resolve.krispytools.com/tools/timeline-renamer/)

---

### Marker Insert

**Automation** · Drop the same clip at every marker: a whoosh, a title, a graphic or a video.

https://github.com/user-attachments/assets/4dda83aa-633a-4bd4-87b5-fa303a5e1b8b

- Place a sound effect, title, graphic or video at every marker.
- A frame offset lets the clip land a few frames before or after each marker.
- Always uses a new track, so your edit stays as it is.

[▶ Watch the demo](https://resolve.krispytools.com/tools/marker-insert/) · [⬇ Download Marker Insert.lua](tools/Automation/Marker%20Insert.lua) · [Tool page](https://resolve.krispytools.com/tools/marker-insert/)

---

### Track Overlay

**Automation** · Cover every clip on a track with a template clip, cut for cut.

https://github.com/user-attachments/assets/dcd051a4-8452-4f83-bfd1-d2fb1d74091d

- An adjustment clip above every shot, ready for a per-shot grade, zoom or effect.
- Also works with graphics, video and audio, like a frame overlay or a whoosh on every cut.
- Dry Run lists exactly what will be placed before anything changes.

[▶ Watch the demo](https://resolve.krispytools.com/tools/track-overlay/) · [⬇ Download Track Overlay.lua](tools/Automation/Track%20Overlay.lua) · [Tool page](https://resolve.krispytools.com/tools/track-overlay/)

---

### Marker Screenshots

**Automation** · Save a still at every marker of one colour, named after the marker.

https://github.com/user-attachments/assets/2c81e018-5318-4e06-b52b-d86fe0a1f986

- One JPEG at every marker, named after the marker.
- Filter by marker colour so only the frames you want are saved.
- Review stills, thumbnails and chapter images in seconds.

[▶ Watch the demo](https://resolve.krispytools.com/tools/marker-screenshots/) · [⬇ Download Marker Screenshots.lua](tools/Automation/Marker%20Screenshots.lua) · [Tool page](https://resolve.krispytools.com/tools/marker-screenshots/)

---

### YouTube Chapter Exporter

**Utilities** · Turn Resolve timeline markers into a ready-to-paste YouTube chapter list.

https://github.com/user-attachments/assets/40f20abb-6fa4-44f2-8f6f-7b1cbeda6865

- Turns your chapter markers into a YouTube-ready chapter list.
- Filter by marker colour so your own notes stay out.
- Adds the 0:00 intro line YouTube needs and saves a .txt file.

[▶ Watch the demo](https://youtu.be/TniY1OCkV7o) · [⬇ Download YouTube Chapter Exporter.lua](tools/Utilities/YouTube%20Chapter%20Exporter.lua) · [Tool page](https://resolve.krispytools.com/tools/youtube-chapter-exporter/)

---

### Resolve Page Time Tracker

**Utilities** · Track active editing time by Resolve page, session, and project.

https://github.com/user-attachments/assets/9dbc8207-7c65-4029-9b44-d8c35f69222e

- Tracks how long you spend on each page: Edit, Color, Fairlight, Deliver.
- Pauses by itself when you are away and resumes when you are back.
- Per-project totals and CSV export for invoices; all data stays on your computer.

[▶ Watch the demo](https://resolve.krispytools.com/tools/resolve-page-time-tracker/) · [⬇ Download Resolve Page Time Tracker.lua](tools/Utilities/Resolve%20Page%20Time%20Tracker.lua) · [Tool page](https://resolve.krispytools.com/tools/resolve-page-time-tracker/)

---

## Install

1. Download the `.lua` file of the tool you want, or the whole repo as a ZIP (green **Code** button > Download ZIP).
2. Copy it into Resolve's Utility scripts folder:
   - **Windows:** `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\`
   - **macOS:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/`
3. Restart Resolve and open the tool from **Workspace > Scripts > Utility**.

## Requirements

- **DaVinci Resolve Studio 19.1 or newer.** Since Resolve 19.1 the free version no longer lets scripts open their own window.
- Windows 10/11 or macOS 12+. One file works on both.
- Video Difference Marker also needs [FFmpeg](https://ffmpeg.org) installed.

Tested in Resolve Studio 21 on Windows 11. macOS support is built in but less tested, so if something breaks on your Mac, please open an issue.

## Bugs and ideas

Open an [issue](../../issues) with your Resolve version, your OS and what happened. Pull requests are welcome.

## Support the project

Everything here is free, also for paid client work. If a tool saved you time, you can [say thanks with any amount](https://buy.polar.sh/polar_cl_O8uLLTvEdos0GJEM7GCTxUdUN4MGWKijaK9a634Bls4). Never required.

## License

[MIT](LICENSE)
