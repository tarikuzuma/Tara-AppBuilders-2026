# Tara — your private, offline Taglish commute copilot

**AppBuilders PH 2026 · on-device AI**

Tara learns from *your own* commutes (jeep, trike, Grab, bus, MRT, walking) and answers questions like
**“Uulan daw, aabot ba ako sa 8AM class kung mag-jeep?”** with a verdict and a leave-by time.
All AI runs on the phone, so your trips, GPS and voice never leave it, and everything works in airplane mode.

## How it works

```
Taglish question / voice / screenshot
        │  on-device AI: understand → structured intent (or read text from an image)
        ▼
Code validates it (keyword parser + whitelists), then computes everything:
median & p80 travel time, leave-by, verdict, fare check, XP, quests
        │
        ▼
Answer + "Code-checked facts" card. A number guard rejects any AI text that
invents or drops a number.
```

**The AI never does math.** Every duration, fare and time on screen comes from code over your own trip history.

## Features
- **Tanong kay Tara.** Taglish questions: can I make it, when to leave, how long, compare modes (“Jeep o Grab pag umuulan?”), cost, and fare check (“₱80 sa trike, overcharge ba?”). Follow-ups like “Eh kung Grab?” use the previous question as context.
- **Leave-by hero.** A verdict-driven card (on time / alis na / late → faster option) with a rain toggle.
- **Hey Tara (voice).** Tap to talk: “track my location now, papunta akong LB bro” starts a GPS-tracked trip, and “nandito na ako” ends it. GPS only runs while the app is open, and it auto-detects arrival.
- **Type-a-trip.** “jeep pauwi 50 mins ₱15 baha sa España” fills in a form for you to confirm. Nothing saves without your OK.
- **Screenshot import.** A ride-receipt screenshot fills in fare, pickup, drop-off and trip time.
- **Pasada (game).** XP from trips, steps (phone step counter), walking and condition tags; levels and titles; streaks with shields; weekly quests picked from your patterns; a shop for Tara personas (Tito / Conyo / Coach / Lola).
- **Barkada board.** Offline multiplayer: friends exchange QR codes that carry scores only, never locations or routes.

## What runs locally vs. what needs internet
| | Where |
|---|---|
| Intent understanding (LLM) | **On-device**: `gemma3-270m` via Cactus |
| Screenshot reading (vision LLM) | **On-device**: `lfm2-vl-450m` via Cactus |
| Voice → text | **On-device**: Android on-device speech recognizer (offline language pack), or Cactus Whisper (`whisper-*`) |
| Stats, verdicts, fare check, XP, quests | **On-device**: plain Dart code |
| Storage (trips, GPS points, steps, XP, friends) | **On-device**: SQLite |
| **Internet** | **Only the one-time model download** on first launch. After that, Tara works fully in airplane mode. |

Notes:
- Cactus telemetry is disabled (`CactusConfig.isTelemetryEnabled = false`) and only local completion mode is used, with no cloud fallback.
- When the phone is online, the Cactus SDK may still look up public model metadata (name, size, quantization) before a completion. No user data is sent. Offline, it uses its cached copy.

## Measured on the demo phone (12 GB RAM, airplane mode)
| Step | Time |
|---|---|
| Understand a Taglish question (`gemma3-270m`) | ~2.3–3.6 s |
| Full answer incl. stats + verdict | ~4–6 s |
| Read a screenshot (`lfm2-vl-450m`, downscaled to 768 px) | ~14 s, peak ~2 GB RAM |

`qwen3-0.6` was tried first, but at ~18 s to understand plus 13 s to rewrite it was too slow, so we switched.

## Models
- `gemma3-270m` — Google Gemma 3 270M (text)
- `lfm2-vl-450m` — Liquid AI LFM2-VL 450M (vision)
- `whisper-base` / `whisper-small` — OpenAI Whisper (speech; optional engine)
- All served through the **Cactus** on-device runtime (pub `cactus`).

## Packages
`cactus`, `sqflite`, `path`, `path_provider`, `geolocator`, `record`, `speech_to_text`, `pedometer`, `permission_handler`,
`qr_flutter`, `mobile_scanner`, `image_picker`, `flutter_tts`, `intl`. Fonts: Manrope and DM Sans (OFL), bundled.

## Disclosure
- **AI dev tools:**
  - Claude Code (Anthropic) was used for planning, coding, testing and on-device debugging.
  - The UI was first designed in Figma Make (AI-assisted); that mock is kept in `design/figma-make-mock/`.
- **Reused code:** none beyond the packages above. The Whisper input padding works around a known padding behaviour in cactus 1.3.0's native transcriber.
- **Demo data:** four weeks of synthetic trips are generated deterministically (`lib/data/seed.dart`) so the demo can show "learns over time".

## Run it
```bash
flutter pub get
flutter run            # on a real arm64 Android phone (the AI runtime needs ARM)
```
On first launch, tap **Download Tara**: this is a one-time model download over Wi-Fi. Then turn on airplane mode and ask away.
**Settings → Diagnostics → Run AI self-test** runs voice clips and images placed in the app's `selftest/` folder through the real on-device pipeline and reports timings.

## Tests
```bash
flutter test
```
The tests cover the stats engine, the Taglish keyword parser, AI-JSON merging and the number guard, fare check, XP/levels/streaks, quests, barkada QR round-trip, the receipt parser, seed robustness for every install weekday, and end-to-end brain answers.

## Team
- Tarikuzuma (Edwin Gumba)
