# Tara — gamified Taglish commute copilot (on-device AI), 10-hour build plan

## Context
Hackathon build. Code freezes **10:00 AM, Oct 10**. It's about 11:30 PM Oct 9.
The working folder `D:\Projects\AI Sfety App` is empty.

**Hackathon rule:** meaningful AI inference must run on the phone, and the app must work in airplane mode.

The original spec had a weak spot: the AI only rephrased numbers, so judges could ask "why not just show a table?"

**New framing:** you *talk* to **Tara** (voice or typed Taglish).
- Tara turns the request into structured actions over *your own* trips.
- The code does all the math, tracking and scoring.
- Tara explains the results back in Taglish.
- A game layer (XP, streaks, shop, offline barkada leaderboard) keeps people logging trips, and logging is what makes Tara smarter.

**What the user decided:**
- Demo phone: Android with 6GB+ RAM.
- Install Flutter on this PC.
- Voice via tap-to-talk.
- Photo feature: Grab screenshot.
- Game: XP + steps + streaks, Pasada Shop, Barkada QR leaderboard.
- Extra AI: Fare check, AI weekly quests.
- **Cut nothing ("all in")**, so we manage scope with a strict build order, feature flags and a hard freeze at 07:45.

**Not selected (cut):** Lakas energy meter, Text-mo-si-Mama SMS, daily recap.

**Environment check:**
- Flutter/Dart: missing (step 0 installs them).
- Android SDK: present.
- Also present: Java, git, gh.
- The AI must be tested on the **real phone**; the Windows emulator can't run the native ARM AI libraries.

## The brain: one pipeline for every input
```
 🎤 "Hey Tara, track my location now, papunta akong LB bro"  (on-device Whisper → text)
 ⌨️ "Uulan daw, aabot ba ako sa 8AM class kung mag-jeep?"
 ⌨️ "₱80 sa trike papuntang school, overcharge ba?"
 ⌨️ "jeep pauwi 50 mins ₱15 baha sa España"
   │ AI job 1 — UNDERSTAND → intent JSON
   │   start_trip | stop_trip | can_i_make_it | when_to_leave | how_long | compare_modes | cost | fare_check | log_trip
   ▼
 CODE validates (whitelists + keyword fallback), maps aliases ("LB") → places, then ACTS:
 start GPS tracking / stats + leave-by + verdict / fare comparison / pre-fill form / award XP
   ▼
   │ AI job 2 — EXPLAIN in Taglish (in the active persona's voice), ONLY code-computed facts
   ▼
 Reply + facts chip ("Based on 6 rainy jeep trips · Home→School") + NUMBER GUARD
```
- **AI job 3:** the vision model reads a Grab screenshot into the trip form.
- **AI job 4:** Tara writes the weekly quests. Code picks the targets and rewards; Tara writes the Taglish challenge text.
- **Number guard:** every number in an AI reply must appear in the facts. If one doesn't, the app falls back to a template Taglish reply.

## Feature list, in build order (earlier = more protected)

### Core (the demo backbone)
| # | Feature | AI? |
|---|---|---|
| 1 | **Places** with aliases (Home, School, Office, LB = Los Baños/UPLB), lat/lng, "Set to current location" | No |
| 2 | **Manual trip log**: route + mode + Start/Stop timer + fare + tags (☔ rain, 🚦 traffic, 🌊 baha) | No |
| 3 | **Seeded demo data**: 4 weeks of trips (rain/rush slowdowns, Grab surges, Home→LB bus, Taglish notes), step history, XP history, one active streak | No |
| 4 | **Stats engine**: filter by route/mode/bucket/weekday/tags → median, p80, count, average fare; relaxes filters when n < 3 | No |
| 5 | **Ask Tara (typed)**: all question intents, including **fare_check** (#15). Facts chip + number guard | **Yes** |
| 6 | **Leave-by card**: next class minus p80 minus a 5-min buffer, with a rain toggle | No |
| 7 | **Type-a-trip**: Taglish note → pre-filled form → user confirms | **Yes** |
| 8 | **"Hey Tara" voice**: push-to-talk → on-device Whisper → same pipeline | **Yes** |
| 9 | **Voice-started tracking**: start_trip/stop_trip. GPS **only while the app is open**, live card with elapsed time + ETA + km, auto-arrive within 200 m | Intent only |
| 10 | **Demo clock override**, so "now" in the video is a believable commute time | No |

### Game layer
| # | Feature | AI? |
|---|---|---|
| 11 | **XP engine** (pure Dart, `xp_events` ledger): +50 per trip, +10 per 1,000 steps, +20 per walking km, +20 per condition tag, +100 at a 7-day streak. **Levels and titles** come from XP thresholds. **Steps** come from the Android step sensor (`pedometer`): daily steps = sensor reading − that day's baseline | No |
| 12 | **Streaks**: consecutive days with ≥1 trip logged; a 🔥 counter on Home | No |
| 13 | **Pasada Shop**: spend XP on items. Every purchase writes a negative XP event | Personas change AI style |
| | • **Tara personas**: Tito, Conyo, Lola, Coach. A persona only changes the explain prompt's style; the number guard still applies | **Yes** |
| | • **Titles/badges**: "Hari ng EDSA", "Baha Survivor", … | No |
| | • **Streak shield**: auto-used once on a missed day | No |
| 14 | **AI weekly quests**: code picks 3 quests from templates using your stats. Examples: lots of trike trips → "walk to the jeep stop 3×"; low steps → "8,000 steps on 4 days"; logging gaps → "log every trip". Code sets the target, tracks progress and pays the reward; Tara writes the Taglish title and pep line (persona-aware, number-guarded) | **Yes** |
| 15 | **Fare check**: `fare_check` intent → code compares against your fare history for that route and mode (median, typical range; flags "mukhang overcharge" if > p90 or > 1.3× median, or "kulang data" if n < 3) → Tara explains | **Yes** |
| 16 | **Barkada QR leaderboard** (offline multiplayer): "My card" QR = {name, week, weekly XP, steps, streak, level, title}, **never locations**. Scan a friend's QR → stored locally → weekly leaderboard. For the demo, friend QR PNGs live in `demo/` | No |

### Extras (last before the freeze)
| # | Feature | AI? |
|---|---|---|
| 17 | **Grab screenshot → trip form** | **Yes** (vision) |
| 18 | **Tara talks back** via `flutter_tts`, only if the phone's TTS works offline | No |

**Stretch / pitch "next":** process-later queue, hands-free wake word, jeepney skins in the shop, energy meter, ETA SMS to family, multi-leg trips. **Never:** background tracking, accounts, cloud sync.

**Feature flags** live in `lib/config/features.dart`. Anything not working at the 07:45 freeze gets switched off, not half-shown.

## UI direction: build from the Figma Make mock, with these fixes
**Source:** `D:\Downloads\Re-plan Commute AI Build (2).zip`, a React/Tailwind mock in `src/App.tsx` and `src/index.css`. It has 6 screens: Home, Tanong, Log, Trips (list + map), Pasada (Quests/Shop/Barkada), Settings.

**Keep (strong):**
- Navy #17233C + lime #D7EF6E + cream #F8F6EF palette.
- Manrope display + DM Sans body.
- The answer-first hero ("Alis ka na by 6:57").
- The Taglish microcopy.
- The "Code-checked facts" card.
- The privacy reminders.
- "Made by Tara, tracked by code" on quests.

**Must fix:**
1. **Type is far too small.** 6–10px is used almost everywhere (eyebrows 7–9, quest kicker 6, YOU badge 5, nav 8, body 11–12). On a real phone it's unreadable, and the video is filmed on a phone. Flutter scale (sp):
   - hero 32, page title 24, section 18
   - body 15, secondary 13, caption/eyebrow 11
   - **minimum 11**
2. **Contrast fails WCAG AA.** Muted grays (#879087, #8a908b, #989d98 on cream) are about 3:1. Olive text #6E813E is about 4:1. Darken muted to ≈#5F665F and accent text to ≈#4F6420. This also matters in sunlight at the jeep stop.
3. **Tap targets are below 48dp.** Affected: Stop, chips, filter pills, shop buttons, rain toggle, icon buttons. Commuters tap one-handed in a moving jeep.
4. **The hero contradicts itself.** It shows "Alis ka na by 6:57" at 7:05 AM. Make the hero **verdict-driven**:
   - 🟢 "May oras ka pa — alis by 7:20"
   - 🟡 "Alis ka na!"
   - 🔴 "Late ka na ng 8 min — Grab: 32 min?" with a one-tap alternative
5. **Voice is buried** as a small row under the Ask box, yet it's demo beat #1. Nav becomes **Home · Tanong · [🎤 Tara] · Trips · Pasada**, with the center button as the mic. Logging moves to a "+" on Trips, a Home quick action, and voice/type ("Tara, log mo…").
6. **Settings is only reachable from the Pasada gear.** Add a gear to the Home header.
7. **The "Google Maps synced" card and fake map break the story.** They imply a cloud import, and real map tiles need internet. Remove both. Keep "Most visited", and optionally draw your own GPS trace with CustomPaint (no tiles).
8. **Copy says "No account, cloud, **or tracking**"**, which is false now. Change it to "No account, no cloud. Tracks only when you ask." Change the "Offline" pill to "On-device AI" plus a live ✈️ indicator when airplane mode is on.
9. **Shop:** personas shown as initials ("CT", "CH") have no character. Give them expressive avatars and a sample line. Fix the mock bug where the quote stays Tito's after equipping another persona. Add a confirm sheet before spending XP.
10. **Leaderboard row** packs 5 columns at 6–9px. Simplify to rank, avatar, name + title, XP, with the streak inline under the name.
11. **Iconography:** emoji tags (🌊☔🚦) clash with the line icons. Pick one style; recommend line icons with color chips.
12. **Fonts must be bundled** as TTFs in `assets/fonts`. The `google_fonts` package downloads at runtime and breaks in airplane mode.

**Missing states and screens to design** (most demo-critical first):
1. **Voice sheet:** listening (waveform + live transcript) → "Nag-iisip si Tara…" → understood card (chips: LB · Bus · Start tracking) → confirm/undo. Error state: "Di kita narinig — ulitin o i-type?"
2. **Visible AI pipeline loader** in Tanong: ① "Naintindihan: ulan + jeep + 8AM" → ② "Kinuha ang 6 rainy trips" → ③ answer. This turns 2–5 s of on-device latency into proof of understand → code → explain.
3. **AI-filled review form:** real editable fields, an "AI" marker on fields Tara filled, unknown fields highlighted. The current Log card is static text.
4. **First launch:** a one-time model download (size, progress, "Download once, offline forever") plus Taglish permission primers (location, mic, activity, camera).
5. **Reward moments:** XP toast (exists), level-up and quest-complete sheet, haptics.
6. **Barkada:** "My card" QR screen and the scanner screen.
7. **Grab screenshot import:** reuse the review form with an image thumbnail.
8. **Empty, low-data and error copy:** "Kulang pa data — 2 trips pa lang", number-guard fallback, model failed to load.

**Implementation:**
- Build `lib/ui/theme.dart` (tokens above) and `lib/ui/components.dart` (Card, Chip, FactsCard, StatTile, PrimaryButton, VoiceSheet, XpToast) **first**. Every screen is built to spec as its feature lands; there's no separate polish pass.
- Port copy and layout from `App.tsx`.
- Reuse the mock's "desktop story" panel as the README hero and the video end card.

## Tech decisions (locked)
- **Flutter**, Android only. **sqflite** for storage. Plain **setState** for state.
- **Packages:** `cactus`, `sqflite`, `geolocator`, `record`, `pedometer`, `permission_handler`, `qr_flutter`, `mobile_scanner`, `image_picker`, `flutter_tts`.
- **AI runtime:** pub `cactus` v1.3.0.
  - `CactusLM`: `downloadModel` / `initializeModel` / `generateCompletion` / `unload`.
  - Images go in through `ChatMessage.images`.
  - Whisper is used for speech-to-text; the exact API gets verified in the spike.
  - Set `CactusConfig.isTelemetryEnabled = false`. **Local mode only**: no hybrid, no token.
- **Models**, configurable in `lib/config/ai_config.dart`:
  - Text: `qwen3-0.6` (`/no_think`). Fallback: `gemma3-270m`.
  - STT: `whisper-base`.
  - Vision: `lfm2-vl-450m`.
  - One model loaded at a time.
- **Fallbacks:** if Whisper mangles Taglish, use `speech_to_text` with `onDevice: true`. If Cactus fails entirely, use `flutter_edge_ai`, behind the same `LocalAI` interface.
- **Robust JSON:** take the first `{...}`, check it against an allowed-values whitelist, and merge it over a keyword fallback parser (ulan, jeep/dyip, trike, grab, "by 8"/"alas-otso", track/papunta, nandito na, overcharge/mahal, strip "hey tara").
- **Internet:** only the first-launch model download. GPS, step sensor and QR scanning all work in airplane mode.

## Data model (sqflite tables)
- `places(id, name, aliases, lat, lng)`
- `trips(id, origin_id, dest_id, mode, start, end, fare, note, tags, source, km)`
- `trip_points(trip_id, t, lat, lng)`
- `daily_steps(date, steps, baseline)`
- `xp_events(id, at, amount, reason, ref_id)`
- `owned_items(item_id, bought_at)`
- `settings(key, value)`: active persona, title, demo clock
- `quests(id, week, type, target, progress, xp_reward, text, status)`
- `friends(name, week, xp, steps, streak, level, title, scanned_at)`
- `queue_jobs`: schema only, used by the stretch queue

## File layout
```
lib/main.dart
lib/config/{ai_config,features}.dart
lib/data/{models,db,seed}.dart
lib/stats/{stats_engine,advisor,fare_check}.dart
lib/game/{xp_engine,streaks,shop,quests,barkada_card}.dart
lib/ai/{local_ai,cactus_ai,prompts,json_utils,intent_parser,personas}.dart
lib/tracking/trip_tracker.dart      lib/sensors/steps.dart      lib/voice/voice_input.dart
lib/ui/{theme,components,voice_sheet}.dart          assets/fonts/{Manrope,DMSans}*.ttf
lib/screens/{onboarding,home,ask,log_trip,trips,game,shop,barkada,settings}_screen.dart
test/{stats_engine,intent_fallback,xp_engine,quests,fare_check,barkada_card}_test.dart
demo/friend_qr_*.png
README.md
```

## Timeline (Claude writes the code; you run it on the phone, approve installs, record and post)
| Time | Step | Gate |
|---|---|---|
| 23:30–00:10 | **Setup**: install Flutter, `flutter doctor`, Android licenses, USB debugging, `flutter create`, `git init`, private GitHub repo | Phone in `flutter devices` |
| 00:10–01:15 | **AI spike on the phone**: qwen3-0.6 intents (timed), whisper-base on "Hey Tara… LB bro", one Grab screenshot | **GATE 01:15**: lock runtime and models |
| 01:15–02:15 | Pure-Dart batch: DB, models, seed, stats, advisor, fare check, XP engine, streaks, quest picker, QR card encode/decode + unit tests | `flutter test` green |
| 02:15–02:45 | **Theme + component kit** from the Figma mock (tokens, bundled fonts, cards, chips, FactsCard, nav with center mic) + first-launch model download screen | Matches the mock at 1:1 on the phone |
| 02:45–03:45 | **Ask Tara** (typed) incl. fare_check, personas, number guard, facts chip, visible pipeline loader | Works in airplane mode |
| 03:45–04:30 | Manual log + Type-a-trip + review form + XP award on save | |
| 04:30–05:45 | Voice + GPS tracking + auto-arrive + step sensor | |
| 05:45–06:30 | Game UI: XP/level/streak header, Pasada Shop, Quests card | |
| 06:30–07:15 | Barkada QR: my card, scanner, leaderboard, demo friend QRs | |
| 07:15–07:45 | Grab screenshot + TTS | |
| **07:45** | **HARD FEATURE FREEZE**: unfinished features turned off with flags | |
| 07:45–08:15 | Full airplane-mode run-through + fixes | |
| 08:15–09:00 | **Record the demo video** (you) | |
| 09:00–09:40 | README with disclosure; repo public; post #AppBuildersPH; submit | Submitted |
| 09:40–10:00 | Buffer | |

**If a block overruns,** its last item moves to after the freeze and only ships if it's done. Core #1–#10 always come first.

## Demo video (under 60 s, so show 6 beats; the rest go in the README with GIFs)
1. Airplane mode on.
2. 🎤 *"Hey Tara, track my location now, papunta akong LB bro"* → tracking card + ETA.
3. ⌨️ *"Uulan daw, aabot ba ako sa 8AM class kung mag-jeep?"* → Taglish verdict + leave-by + facts chip.
4. ⌨️ *"₱80 sa trike, overcharge ba?"* → fare check from your own history.
5. Save a trip → **+70 XP** pop-up, quest progress ticks, 🔥 streak → buy **Conyo Tara** in the shop → same answer in conyo voice, same numbers.
6. Scan a friend's QR → barkada leaderboard, offline.
7. End card: "All AI ran on this phone. Tara only tracks when you ask; your location never leaves it."

## Pitch answers
- **"Why AI?"** You *talk* to it in Taglish. It turns messy requests into precise actions over your own data, and writes your quests and replies in your chosen persona.
- **"Hallucinations?"** No number comes from the AI. Code computes everything, and a number guard rejects any reply with a number that isn't in the facts.
- **"Why local?"** Voice, GPS and step data are the most sensitive data on a phone, and they never leave it. Even multiplayer is phone-to-phone by QR, with no server.

## Verification
- `flutter test`: stats (median, p80, relaxation), keyword intent fallback (about 15 Taglish lines incl. fare_check and start_trip), XP rules, streak + shield, quest picker, fare-check thresholds, QR card round-trip.
- **On the phone** with `flutter run`:
  - 10 typed questions and 3 spoken commands map to the right intents, with latency logged.
  - The number guard catches a deliberately bad reply.
  - Buying a persona deducts XP and changes the style but not the numbers.
  - Scanning a `demo/` QR adds a friend.
  - Auto-arrive triggers when the destination is set to the current spot.
- **Airplane-mode checklist:** cold start → voice tracking → Ask → fare check → log trip (XP) → shop → barkada scan → screenshot.
- **README:** models, every package, Claude Code as the AI dev tool, and that only the first model download needs internet.
