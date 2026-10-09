import { FormEvent, ReactNode, useState } from "react";

type IconName =
  | "home"
  | "chat"
  | "plus"
  | "route"
  | "settings"
  | "rain"
  | "arrow"
  | "spark"
  | "shield"
  | "clock"
  | "car"
  | "jeep"
  | "send"
  | "back"
  | "check"
  | "chevron"
  | "mic"
  | "trophy"
  | "flame"
  | "foot"
  | "qr"
  | "location"
  | "store"
  | "lock";

function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  const paths: Record<IconName, ReactNode> = {
    home: <><path d="m3 11 9-7 9 7" /><path d="M5 10v10h14V10M9 20v-6h6v6" /></>,
    chat: <><path d="M20 15a4 4 0 0 1-4 4H8l-5 3 1.4-4.2A7 7 0 0 1 3 13V8a4 4 0 0 1 4-4h9a4 4 0 0 1 4 4Z" /><path d="M8 10h8M8 14h5" /></>,
    plus: <><path d="M12 5v14M5 12h14" /></>,
    route: <><circle cx="6" cy="5" r="2" /><circle cx="18" cy="19" r="2" /><path d="M8 5h5a3 3 0 0 1 0 6H9a3 3 0 0 0 0 6h7" /></>,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H3v-4h.1a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3A1.7 1.7 0 0 0 10 3V3h4v.1a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" /></>,
    rain: <><path d="M7 15a4 4 0 1 1 1-7.9A5 5 0 0 1 17.8 9 3 3 0 0 1 18 15Z" /><path d="m8 18-1 2M13 18l-1 2M18 18l-1 2" /></>,
    arrow: <><path d="M5 12h14M14 7l5 5-5 5" /></>,
    spark: <><path d="m12 3 .8 3.2A4 4 0 0 0 15.8 9l3.2.8-3.2.8a4 4 0 0 0-3 2.8L12 17l-.8-3.4a4 4 0 0 0-3-2.8L5 10l3.2-.8a4 4 0 0 0 3-3Z" /><path d="m18 3 .3 1.2.9.3-.9.3L18 6l-.3-1.2-.9-.3.9-.3Z" /></>,
    shield: <><path d="M12 3 5 6v5c0 4.6 2.8 8 7 10 4.2-2 7-5.4 7-10V6Z" /><path d="m9 12 2 2 4-5" /></>,
    clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>,
    car: <><path d="m5 11 2-5h10l2 5M4 11h16v7H4Z" /><path d="M7 18v2M17 18v2M7 14h.1M17 14h.1" /></>,
    jeep: <><path d="M4 7h16v10H4ZM7 7V4h10v3M7 17v2M17 17v2" /><path d="M4 12h16M8 7v5M16 7v5" /></>,
    send: <><path d="m3 11 18-8-8 18-2-8Z" /><path d="m11 13 10-10" /></>,
    back: <><path d="m15 18-6-6 6-6" /></>,
    check: <><path d="m5 12 4 4L19 6" /></>,
    chevron: <><path d="m9 18 6-6-6-6" /></>,
    mic: <><rect height="11" rx="4" width="7" x="8.5" y="3" /><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M9 21h6" /></>,
    trophy: <><path d="M8 4h8v5a4 4 0 0 1-8 0ZM9 20h6M12 13v7" /><path d="M8 6H4v2a4 4 0 0 0 4 4M16 6h4v2a4 4 0 0 1-4 4" /></>,
    flame: <><path d="M12 22c4 0 7-2.6 7-6.5 0-2.7-1.5-5.3-4.6-8.2.1 2.2-1 3.4-2 4.2.2-4-1.8-7.1-4.4-9.5.2 4-3 6.5-3 11.4C5 18.5 8 22 12 22Z" /><path d="M9.5 18c0-1.9 1.2-3.1 2.5-4.4 1.5 1.4 2.5 2.8 2.5 4.4a2.5 2.5 0 0 1-5 0Z" /></>,
    foot: <><path d="M15.8 5.2c.7 2.3-.1 4.6-1.8 5.1s-3.6-1-4.3-3.3.1-4.6 1.8-5.1 3.6 1 4.3 3.3ZM8.8 15.6c.5 1.7-.1 3.4-1.3 3.8s-2.7-.7-3.2-2.4.1-3.4 1.3-3.8 2.7.7 3.2 2.4Z" /><path d="M13 11c-1 2-1.5 4.3-.8 6.4.6 2 2.4 3.1 4 2.6 1.8-.6 2.4-2.4 1.6-4.2-.7-1.6-2.3-3.3-4.8-4.8Z" /></>,
    qr: <><rect height="6" rx="1" width="6" x="3" y="3" /><rect height="6" rx="1" width="6" x="15" y="3" /><rect height="6" rx="1" width="6" x="3" y="15" /><path d="M15 15h2v2h-2zM19 15h2v2h-2zM15 19h2v2h-2zM19 19h2v2h-2z" /></>,
    location: <><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z" /><circle cx="12" cy="10" r="2.5" /></>,
    store: <><path d="M4 10v10h16V10M3 4h18l-1 6a3 3 0 0 1-4 1 3 3 0 0 1-4 0 3 3 0 0 1-4 0 3 3 0 0 1-4-1ZM9 20v-5h6v5" /></>,
    lock: <><rect height="10" rx="2" width="14" x="5" y="11" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></>,
  };

  return (
    <svg aria-hidden="true" fill="none" height={size} viewBox="0 0 24 24" width={size}>
      <g stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8">
        {paths[name]}
      </g>
    </svg>
  );
}

const prompts = [
  "Aabot ba ako sa 8AM class kung mag-jeep?",
  "Jeep o Grab pag umuulan?",
  "Magkano usually ang Grab pauwi?",
];

function Nav({ active, onChange }: { active: string; onChange: (value: string) => void }) {
  const items: { id: string; label: string; icon: IconName }[] = [
    { id: "home", label: "Home", icon: "home" },
    { id: "ask", label: "Tanong", icon: "chat" },
    { id: "log", label: "Log", icon: "plus" },
    { id: "trips", label: "Trips", icon: "route" },
    { id: "game", label: "Pasada", icon: "trophy" },
  ];

  return (
    <nav className="bottom-nav" aria-label="Main navigation">
      {items.map((item) => (
        <button
          className={`nav-item ${active === item.id ? "active" : ""} ${item.id === "log" ? "nav-log" : ""}`}
          key={item.id}
          onClick={() => onChange(item.id)}
          type="button"
        >
          <span className="nav-icon"><Icon name={item.icon} size={item.id === "log" ? 24 : 21} /></span>
          <span>{item.label}</span>
        </button>
      ))}
    </nav>
  );
}

function Header({ label = "Magandang gabi, Mia" }: { label?: string }) {
  return (
    <header className="topbar">
      <div className="brandmark"><span>T</span></div>
      <div className="topbar-title">
        <span className="eyebrow">{label}</span>
        <strong>Tara?</strong>
      </div>
      <button className="status-pill" type="button">
        <span className="status-dot" />
        Offline
      </button>
    </header>
  );
}

function Home({ onAsk, onNavigate }: { onAsk: (text?: string) => void; onNavigate: (id: string) => void }) {
  const [rain, setRain] = useState(true);
  const [tracking, setTracking] = useState(false);

  return (
    <main className="screen home-screen">
      <Header />
      <button className="player-strip" onClick={() => onNavigate("game")} type="button">
        <span className="level-medal">12</span>
        <span className="player-copy"><strong>Street Smart</strong><small><i><em /></i> 2,460 / 3,000 XP</small></span>
        <span className="streak-count"><Icon name="flame" size={18} /><strong>6</strong><small>days</small></span>
        <Icon name="chevron" size={17} />
      </button>
      {tracking && (
        <section className="tracking-card">
          <span className="tracking-pulse"><i /></span>
          <div><span>LIVE TRIP · TO LOS BAÑOS</span><strong>42 min <small>ETA 8:17 AM</small></strong><p>18.4 km remaining</p></div>
          <button onClick={() => setTracking(false)} type="button">Stop</button>
        </section>
      )}
      <section className="hero-copy">
        <span className="date-label">TUESDAY · 7:05 AM</span>
        <h1>Alis ka na by <em>{rain ? "6:57" : "7:08"}</em></h1>
        <p>Para umabot sa 8:00 AM class mo.</p>
      </section>

      <section className="leave-card">
        <div className="weather-orb"><Icon name={rain ? "rain" : "spark"} size={28} /></div>
        <div className="leave-route">
          <div className="route-points" aria-hidden="true"><i /><span /><i /></div>
          <div className="route-labels">
            <div><span>FROM</span><strong>Home</strong></div>
            <div><span>TO</span><strong>School</strong></div>
          </div>
        </div>
        <div className="leave-meta">
          <div><Icon name="jeep" size={19} /><span>Jeepney</span></div>
          <div><Icon name="clock" size={19} /><span>{rain ? "58" : "47"} min p80</span></div>
          <button
            aria-pressed={rain}
            className={`rain-toggle ${rain ? "on" : ""}`}
            onClick={() => setRain(!rain)}
            type="button"
          >
            <span><Icon name="rain" size={17} /> Rain</span>
            <i />
          </button>
        </div>
        <div className="leave-note">
          <span><Icon name="shield" size={17} /></span>
          <p>May <strong>5-min safety buffer</strong> na kasama.</p>
        </div>
      </section>

      <section className="ask-launch">
        <div>
          <span className="section-kicker"><Icon name="spark" size={16} /> TANONG KAY TARA</span>
          <h2>May biyahe ka sa isip?</h2>
        </div>
        <button className="ask-box" onClick={() => onAsk()} type="button">
          <span>“Uulan daw, aabot ba ako?”</span>
          <i><Icon name="arrow" size={19} /></i>
        </button>
        <button className={`voice-launch ${tracking ? "active" : ""}`} onClick={() => setTracking(true)} type="button">
          <span><Icon name="mic" size={19} /></span>
          <div><strong>{tracking ? "Tracking your trip" : "Tap to talk"}</strong><small>{tracking ? "“Papunta akong LB bro”" : "“Hey Tara, track my trip…”"}</small></div>
          {tracking ? <i className="voice-wave"><b /><b /><b /></i> : <Icon name="chevron" size={18} />}
        </button>
        <div className="privacy-note"><Icon name="shield" size={15} /> On-device lang. Walang lumalabas sa phone mo.</div>
      </section>

      <button className="quest-teaser" onClick={() => onNavigate("game")} type="button">
        <span className="quest-icon"><Icon name="trophy" size={21} /></span>
        <div><span>WEEKLY QUEST</span><strong>Lakad muna, bes!</strong><small>Walk to the jeep stop · 2 of 3 trips</small><i><em /></i></div>
        <b>+180<small> XP</small></b>
      </button>

      <section className="recent-row">
        <div className="section-heading">
          <h2>Recent trips</h2>
          <button onClick={() => onNavigate("trips")} type="button">See all</button>
        </div>
        <article className="trip-mini">
          <div className="trip-mode jeep"><Icon name="jeep" size={22} /></div>
          <div className="trip-main"><strong>School <Icon name="arrow" size={14} /> Home</strong><span>Yesterday · 5:42 PM</span></div>
          <div className="trip-stat"><strong>50 min</strong><span>₱15</span></div>
        </article>
      </section>
      <Nav active="home" onChange={onNavigate} />
    </main>
  );
}

function AskScreen({ initial, onBack, onNavigate }: { initial: string; onBack: () => void; onNavigate: (id: string) => void }) {
  const [input, setInput] = useState("");
  const [question, setQuestion] = useState(initial);
  const [answer, setAnswer] = useState(initial ? "result" : "empty");
  const [listening, setListening] = useState(false);
  const isGrab = /grab/i.test(question);
  const isFare = /₱|overcharge|mahal|fare/i.test(question);

  function submit(event: FormEvent) {
    event.preventDefault();
    if (!input.trim()) return;
    setQuestion(input);
    setAnswer("loading");
    setInput("");
    window.setTimeout(() => setAnswer("result"), 700);
  }

  return (
    <main className="screen ask-screen">
      <header className="ask-header">
        <button className="icon-button" onClick={onBack} type="button"><Icon name="back" /></button>
        <div><span className="eyebrow">YOUR COMMUTE COPILOT</span><strong>Tanong kay Tara</strong></div>
        <span className="local-badge"><span /> Local AI</span>
      </header>

      <div className="chat-area">
        {answer === "empty" ? (
          <div className="ask-empty">
            <div className="tara-orb"><Icon name="spark" size={30} /></div>
            <h1>Kahit Taglish, gets ko.</h1>
            <p>Tanong mo kung kailan aalis, gaano katagal, o anong sakay ang mas okay.</p>
            <div className="prompt-list">
              {prompts.map((prompt) => <button key={prompt} onClick={() => { setQuestion(prompt); setAnswer("result"); }} type="button">{prompt}<Icon name="chevron" size={18} /></button>)}
            </div>
          </div>
        ) : (
          <>
            <div className="message user-message">{question || prompts[0]}</div>
            {answer === "loading" ? (
              <div className="thinking"><span /><span /><span /> Tinitingnan ang trips mo…</div>
            ) : (
              <div className="answer-block">
                <div className="tara-label"><span><Icon name="spark" size={15} /></span> TARA</div>
                <div className="message tara-message">
                  {isFare ? (
                    <p><strong>Mukhang overcharge, bes.</strong> Usually <mark>₱45–₱60</mark> lang ang trike mo sa route na ’to. Ang <mark>₱80</mark> ay above sa usual range mo.</p>
                  ) : isGrab ? (
                    <p><strong>Grab ang mas safe bet ngayon.</strong> Pag maulan, around <mark>32 mins</mark> ang biyahe mo at <mark>₱248</mark> average fare. Mas mabilis siya ng <mark>26 mins</mark> kaysa jeep.</p>
                  ) : (
                    <p><strong>Medyo tight na.</strong> Pag umuulan, umaabot ng <mark>58 mins</mark> ang jeep mo papuntang school. Dapat nakaalis ka by <mark>6:57 AM</mark> para umabot sa 8:00.</p>
                  )}
                  <p className="answer-nudge">{isFare ? "Based ito sa sarili mong past trike fares." : isGrab ? "May surge, pero aabot ka." : "Kung aalis ka ngayon, 8 mins kang late. Grab na lang?"}</p>
                </div>
                <div className="facts-card">
                  <div className="facts-title"><Icon name="shield" size={16} /><strong>CODE-CHECKED FACTS</strong><span>Numbers verified</span></div>
                  <div className="facts-grid">
                    <div><span>{isFare ? "₱52" : isGrab ? "32" : "58"}</span><small>{isFare ? "median fare" : "mins · p80"}</small></div>
                    <div><span>{isFare ? "11" : isGrab ? "₱248" : "6"}</span><small>{isFare ? "past trips" : isGrab ? "avg fare" : "rainy trips"}</small></div>
                    <div><span>{isFare ? "₱80" : "AM"}</span><small>{isFare ? "fare asked" : "rush hour"}</small></div>
                  </div>
                  <p>Home → School · {isFare ? "Trike · Fare history" : `${isGrab ? "Grab" : "Jeepney"} · Rain`}</p>
                </div>
                {!isGrab && !isFare && <button className="follow-up" onClick={() => { setQuestion("Eh kung Grab?"); setAnswer("result"); }} type="button"><Icon name="car" size={19} /> Eh kung Grab?<Icon name="arrow" size={18} /></button>}
              </div>
            )}
          </>
        )}
      </div>

      <form className="composer" onSubmit={submit}>
        <input aria-label="Ask Tara" onChange={(e) => setInput(e.target.value)} placeholder="Tanong tungkol sa biyahe…" value={input} />
        <button
          aria-label="Talk to Tara"
          className={listening ? "listening" : "voice-compose"}
          onClick={() => {
            setListening(true);
            window.setTimeout(() => {
              setListening(false);
              setQuestion("₱80 sa trike papuntang school, overcharge ba?");
              setAnswer("result");
            }, 900);
          }}
          type="button"
        ><Icon name="mic" size={19} /></button>
        <button aria-label="Send question" className="send-compose" type="submit"><Icon name="send" size={19} /></button>
      </form>
      <Nav active="ask" onChange={onNavigate} />
    </main>
  );
}

function LogTrip({ onNavigate }: { onNavigate: (id: string) => void }) {
  const [smart, setSmart] = useState(true);
  const [saved, setSaved] = useState(false);

  return (
    <main className="screen secondary-screen">
      <Header label="ADD TO YOUR HISTORY" />
      <section className="page-title"><span className="date-label">QUICK LOG</span><h1>Kamusta ang biyahe?</h1><p>I-type mo lang naturally. Ikaw pa rin ang magco-confirm.</p></section>
      <div className="mode-tabs"><button className={smart ? "active" : ""} onClick={() => setSmart(true)} type="button"><Icon name="spark" size={17} /> Type-a-trip</button><button className={!smart ? "active" : ""} onClick={() => setSmart(false)} type="button"><Icon name="clock" size={17} /> Manual</button></div>
      <section className="log-card">
        {smart && <div className="note-preview">“jeep pauwi 50 mins ₱15 baha sa España”<span><Icon name="check" size={15} /> Understood on-device</span></div>}
        <div className="field-label">ROUTE</div>
        <div className="route-selector"><strong>School</strong><Icon name="arrow" /><strong>Home</strong></div>
        <div className="form-grid">
          <div><span>MODE</span><strong><Icon name="jeep" size={18} /> Jeepney</strong></div>
          <div><span>DURATION</span><strong>50 min</strong></div>
          <div><span>FARE</span><strong>₱15</strong></div>
          <div><span>WHEN</span><strong>Now</strong></div>
        </div>
        <div className="field-label">CONDITIONS</div>
        <div className="tag-row"><button className="selected" type="button">🌊 Baha</button><button type="button">☔ Rain</button><button type="button">🚦 Traffic</button></div>
        <div className="field-label">NOTE</div>
        <div className="note-field">baha sa España</div>
      </section>
      <button className={`primary-button ${saved ? "saved" : ""}`} onClick={() => setSaved(true)} type="button">{saved ? <><Icon name="check" /> Saved to your trips</> : "Confirm & save trip"}</button>
      {saved && <div className="xp-toast"><span>+70</span><div><strong>XP earned!</strong><small>Trip + condition tag</small></div><Icon name="spark" size={19} /></div>}
      <Nav active="log" onChange={onNavigate} />
    </main>
  );
}

function Trips({ onNavigate }: { onNavigate: (id: string) => void }) {
  const [view, setView] = useState<"list" | "map">("list");
  const [activeRoute, setActiveRoute] = useState("School");
  const trips = [
    ["School", "Home", "Jeepney", "50 min", "₱15", "Yesterday · 5:42 PM", "🌊 Baha"],
    ["Home", "School", "Grab", "31 min", "₱236", "Mon · 7:11 AM", "☔ Rain"],
    ["Home", "School", "Jeepney", "56 min", "₱15", "Fri · 6:58 AM", "☔ Rain"],
    ["Office", "Home", "MRT + Jeep", "44 min", "₱42", "Thu · 6:16 PM", "🚦 Traffic"],
  ];
  return (
    <main className="screen secondary-screen">
      <Header label="YOUR LOCAL HISTORY" />
      <section className="page-title compact"><span className="date-label">LAST 4 WEEKS</span><h1>Mga biyahe mo</h1><p>28 trips · stored only on this phone</p></section>
      <div className="view-switch" aria-label="Trip view">
        <button className={view === "list" ? "active" : ""} onClick={() => setView("list")} type="button"><Icon name="route" size={16} /> List</button>
        <button className={view === "map" ? "active" : ""} onClick={() => setView("map")} type="button"><Icon name="home" size={16} /> Map</button>
      </div>
      {view === "list" ? (
        <>
          <div className="filter-row"><button className="active" type="button">All</button><button type="button">Jeepney</button><button type="button">Grab</button><button type="button">Rain</button></div>
          <div className="trips-list">
            {trips.map((trip) => (
              <article className="trip-row" key={trip[5]}>
                <div className={`trip-mode ${trip[2] === "Grab" ? "grab" : "jeep"}`}><Icon name={trip[2] === "Grab" ? "car" : "jeep"} size={21} /></div>
                <div className="trip-main"><strong>{trip[0]} <Icon name="arrow" size={13} /> {trip[1]}</strong><span>{trip[5]} · {trip[2]}</span><small>{trip[6]}</small></div>
                <div className="trip-stat"><strong>{trip[3]}</strong><span>{trip[4]}</span></div>
              </article>
            ))}
          </div>
        </>
      ) : (
        <div className="map-view">
          <div className="sync-card">
            <span className="sync-icon"><Icon name="check" size={16} /></span>
            <div><strong>Google Maps synced</strong><small>Today, 6:42 AM · 14 places found</small></div>
            <button type="button">Sync</button>
          </div>
          <div className="map-canvas">
            <svg className="map-roads" preserveAspectRatio="none" viewBox="0 0 360 290">
              <path className="road major" d="M-10 236C59 203 95 209 133 170S184 91 239 84s91 16 136-28" />
              <path className="road" d="M36-8c17 73 31 117 82 135s101 32 104 169" />
              <path className="road" d="M-9 62c82 12 110 8 157-16s99-22 119 7 27 90 103 109" />
              <path className="road" d="M5 276c62-55 100-61 151-42s116 2 151-45 52-49 71-48" />
              <path className="route-line shadow" d="M70 221C104 190 122 177 150 156S200 110 248 77" />
              <path className="route-line" d="M70 221C104 190 122 177 150 156S200 110 248 77" />
            </svg>
            <span className="district d1">QUEZON CITY</span>
            <span className="district d2">MANILA</span>
            <span className="district d3">SAN JUAN</span>
            <span className="map-label l1">Katipunan Ave</span>
            <span className="map-label l2">España Blvd</span>
            <button className="map-pin home-pin" aria-label="Home, visited 18 times" type="button"><span><Icon name="home" size={15} /></span><small>Home</small></button>
            <button className="map-pin school-pin" aria-label="School, visited 16 times" type="button"><span><b>16</b></span><small>School</small></button>
            <button className="map-pin office-pin" aria-label="Office, visited 7 times" type="button"><span><b>7</b></span><small>Office</small></button>
            <button className="map-pin cafe-pin" aria-label="Cafe, visited 3 times" type="button"><span><b>3</b></span><small>Café</small></button>
            <div className="map-legend"><i /> Most frequent route</div>
          </div>
          <div className="map-section-title">
            <div><span className="section-kicker">YOUR ROUTINES</span><h2>Most visited</h2></div>
            <span>Past 30 days</span>
          </div>
          <div className="route-frequency">
            {[
              { place: "School", meta: "Home → School", count: 16, bar: "full" },
              { place: "Office", meta: "Home → Office", count: 7, bar: "medium" },
              { place: "Café", meta: "School → Café", count: 3, bar: "short" },
            ].map((route) => (
              <button className={activeRoute === route.place ? "active" : ""} key={route.place} onClick={() => setActiveRoute(route.place)} type="button">
                <span className="frequency-rank">{route.place === "School" ? "01" : route.place === "Office" ? "02" : "03"}</span>
                <span className="frequency-copy"><strong>{route.place}</strong><small>{route.meta}</small><i><em className={route.bar} /></i></span>
                <span className="frequency-count"><strong>{route.count}×</strong><small>visits</small></span>
              </button>
            ))}
          </div>
          <p className="map-privacy"><Icon name="shield" size={14} /> Imported places and routes stay on this phone.</p>
        </div>
      )}
      <Nav active="trips" onChange={onNavigate} />
    </main>
  );
}

function Settings({ onNavigate }: { onNavigate: (id: string) => void }) {
  const [demo, setDemo] = useState(true);
  return (
    <main className="screen secondary-screen">
      <Header label="PRIVACY & PREFERENCES" />
      <section className="page-title compact"><span className="date-label">SETTINGS</span><h1>Ikaw ang may control.</h1><p>Everything stays on your device.</p></section>
      <section className="settings-group">
        <span className="group-label">YOUR PLACES</span>
        {["Home", "School", "Office"].map((place, i) => <button className="setting-row" key={place} type="button"><span className="place-dot">{i + 1}</span><strong>{place}</strong><Icon name="chevron" size={18} /></button>)}
      </section>
      <section className="settings-group">
        <span className="group-label">DEMO</span>
        <button className="setting-row tall" onClick={() => setDemo(!demo)} type="button"><span className="setting-icon"><Icon name="clock" /></span><div><strong>Demo clock</strong><small>Pin now to Tue, 7:05 AM</small></div><i className={`switch ${demo ? "on" : ""}`}><span /></i></button>
      </section>
      <section className="device-card"><span><Icon name="shield" size={25} /></span><div><strong>Private by design</strong><p>AI and trip history run locally. No account, cloud, or tracking.</p></div><small>READY OFFLINE</small></section>
      <Nav active="settings" onChange={onNavigate} />
    </main>
  );
}

function Game({ onNavigate }: { onNavigate: (id: string) => void }) {
  const [tab, setTab] = useState<"quests" | "shop" | "barkada">("quests");
  const [xp, setXp] = useState(2460);
  const [persona, setPersona] = useState("Tito Tara");
  const [scanned, setScanned] = useState(false);
  const shopItems = [
    { name: "Conyo Tara", note: "Like, commute smart, bestie.", cost: 400, icon: "CT" },
    { name: "Coach Tara", note: "Direct, upbeat, no excuses.", cost: 550, icon: "CH" },
    { name: "Lola Tara", note: "Warm advice, may baon na care.", cost: 650, icon: "LT" },
    { name: "Streak shield", note: "Protect one missed day.", cost: 300, icon: "SS" },
  ];

  function buy(name: string, cost: number) {
    if (xp < cost) return;
    setXp(xp - cost);
    setPersona(name);
  }

  return (
    <main className="screen secondary-screen game-screen">
      <header className="game-header">
        <div className="brandmark"><span>T</span></div>
        <div><span className="eyebrow">PASADA CLUB</span><strong>Your commute game</strong></div>
        <button className="icon-button" onClick={() => onNavigate("settings")} type="button"><Icon name="settings" size={19} /></button>
      </header>
      <section className="player-card">
        <div className="player-card-top">
          <span className="big-medal"><Icon name="trophy" size={25} /><b>12</b></span>
          <div><span>LEVEL 12</span><h1>Street Smart</h1><p>Next: Hari ng Kalsada</p></div>
          <span className="card-streak"><Icon name="flame" size={20} /><strong>6</strong><small>day streak</small></span>
        </div>
        <div className="xp-progress"><div><span>2,460 XP</span><small>540 to level 13</small></div><i><em /></i></div>
        <div className="player-stats"><span><Icon name="foot" size={17} /><b>8,420</b><small>steps today</small></span><span><Icon name="route" size={17} /><b>28</b><small>trips logged</small></span><span><Icon name="shield" size={17} /><b>1</b><small>shield</small></span></div>
      </section>
      <div className="game-tabs">
        <button className={tab === "quests" ? "active" : ""} onClick={() => setTab("quests")} type="button"><Icon name="trophy" size={16} /> Quests</button>
        <button className={tab === "shop" ? "active" : ""} onClick={() => setTab("shop")} type="button"><Icon name="store" size={16} /> Shop</button>
        <button className={tab === "barkada" ? "active" : ""} onClick={() => setTab("barkada")} type="button"><Icon name="qr" size={16} /> Barkada</button>
      </div>

      {tab === "quests" && (
        <section className="game-panel">
          <div className="panel-heading"><div><span className="section-kicker">WEEKLY CHALLENGES</span><h2>Tara, level up!</h2></div><span>4d 11h left</span></div>
          <article className="quest-card featured">
            <span className="quest-badge"><Icon name="foot" size={23} /></span>
            <div className="quest-content"><span>PERSONALIZED FOR YOU</span><strong>Lakad muna, bes!</strong><p>Walk to the jeep stop instead of taking a trike.</p><div><i><em /></i><b>2 / 3 trips</b></div></div>
            <span className="reward">+180<small>XP</small></span>
          </article>
          <article className="quest-card">
            <span className="quest-badge blue"><Icon name="route" size={22} /></span>
            <div className="quest-content"><strong>Walang mintis</strong><p>Log every commute for 5 days.</p><div><i><em className="four-fifths" /></i><b>4 / 5 days</b></div></div>
            <span className="reward">+250<small>XP</small></span>
          </article>
          <article className="quest-card">
            <span className="quest-badge navy"><Icon name="foot" size={22} /></span>
            <div className="quest-content"><strong>8K era mo na</strong><p>Reach 8,000 steps on 4 days.</p><div><i><em className="half" /></i><b>2 / 4 days</b></div></div>
            <span className="reward">+300<small>XP</small></span>
          </article>
          <div className="ai-quest-note"><Icon name="spark" size={16} /><p><strong>Made by Tara, tracked by code.</strong> Targets come from your commute patterns; rewards and progress never rely on AI guesses.</p></div>
        </section>
      )}

      {tab === "shop" && (
        <section className="game-panel">
          <div className="shop-balance"><span>AVAILABLE BALANCE</span><strong><Icon name="spark" size={18} /> {xp.toLocaleString()} XP</strong></div>
          <div className="active-persona"><span className="persona-avatar">TT</span><div><span>ACTIVE VOICE</span><strong>{persona}</strong><small>“Sige, iho. Tara na’t bumiyahe.”</small></div><Icon name="check" size={19} /></div>
          <div className="panel-heading"><div><span className="section-kicker">PASADA SHOP</span><h2>Unlock your vibe</h2></div></div>
          <div className="shop-grid">
            {shopItems.map((item) => {
              const owned = persona === item.name;
              return (
                <article className={`shop-item ${owned ? "owned" : ""}`} key={item.name}>
                  <span className="shop-avatar">{item.icon}</span>
                  <strong>{item.name}</strong><p>{item.note}</p>
                  <button disabled={owned || xp < item.cost} onClick={() => buy(item.name, item.cost)} type="button">{owned ? "Equipped" : <><Icon name="spark" size={13} /> {item.cost} XP</>}</button>
                </article>
              );
            })}
          </div>
        </section>
      )}

      {tab === "barkada" && (
        <section className="game-panel">
          <div className="panel-heading"><div><span className="section-kicker">OFFLINE LEADERBOARD</span><h2>Barkada board</h2></div><span>This week</span></div>
          <div className="barkada-actions">
            <button type="button"><span className="mini-qr"><i /><i /><i /></span><div><strong>My card</strong><small>Share stats, never routes</small></div><Icon name="chevron" size={17} /></button>
            <button onClick={() => setScanned(true)} type="button"><span><Icon name="qr" size={22} /></span><div><strong>{scanned ? "Jolo added!" : "Scan a friend"}</strong><small>{scanned ? "Saved on this phone" : "Works without internet"}</small></div><Icon name={scanned ? "check" : "chevron"} size={17} /></button>
          </div>
          <div className="leaderboard">
            {[
              ["1", "Bea", "Campus Navigator", "3,120", "9", "B"],
              ["2", "Mia", "Street Smart", "2,460", "6", "M"],
              ["3", scanned ? "Jolo" : "Paolo", "Biyahe Rookie", scanned ? "2,180" : "1,940", scanned ? "5" : "3", scanned ? "J" : "P"],
              ["4", "Kaye", "Lakbay Local", "1,620", "2", "K"],
            ].map((friend) => (
              <div className={`leader-row ${friend[1] === "Mia" ? "me" : ""}`} key={friend[1]}>
                <b>{friend[0]}</b><span className="friend-avatar">{friend[5]}</span><div><strong>{friend[1]} {friend[1] === "Mia" && <small>YOU</small>}</strong><span>{friend[2]}</span></div><p><strong>{friend[3]}</strong><small>weekly XP</small></p><span className="friend-streak"><Icon name="flame" size={13} />{friend[4]}</span>
              </div>
            ))}
          </div>
          <p className="map-privacy"><Icon name="lock" size={14} /> QR cards share scores only — never locations or routes.</p>
        </section>
      )}
      <Nav active="game" onChange={onNavigate} />
    </main>
  );
}

export default function App() {
  const [screen, setScreen] = useState("home");
  const [initialQuestion, setInitialQuestion] = useState("");

  function openAsk(text = "") {
    setInitialQuestion(text);
    setScreen("ask");
  }

  return (
    <div className="app-shell">
      <div className="desktop-story" aria-hidden="true">
        <div className="story-brand"><span>T</span><strong>Tara?</strong></div>
        <h2>Your commute,<br /><em>mas gets na.</em></h2>
        <p>Private, on-device commute advice based on your real trips — even without signal.</p>
        <div className="story-points"><span><Icon name="spark" /> Understands Taglish</span><span><Icon name="shield" /> Your data stays yours</span></div>
        <small>COMMUTE AI · BUILT FOR THE PHILIPPINES</small>
      </div>
      <div className="phone-frame">
        {screen === "home" && <Home onAsk={openAsk} onNavigate={setScreen} />}
        {screen === "ask" && <AskScreen initial={initialQuestion} onBack={() => setScreen("home")} onNavigate={setScreen} />}
        {screen === "log" && <LogTrip onNavigate={setScreen} />}
        {screen === "trips" && <Trips onNavigate={setScreen} />}
        {screen === "game" && <Game onNavigate={setScreen} />}
        {screen === "settings" && <Settings onNavigate={setScreen} />}
      </div>
    </div>
  );
}
