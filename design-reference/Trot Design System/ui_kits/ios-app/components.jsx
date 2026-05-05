// Trot iOS UI kit — shared components
// Loaded after React + ios-frame + tweaks-panel
// All exports go on `window` at the bottom.

const trotTokens = {
  primary: '#E97451', primaryPressed: '#D5613F',
  secondary: '#2F5D50',
  surface: '#FAF7F2', elevated: '#FFFFFF', sunken: '#F2EDE4',
  textPrimary: '#1F1B16', textSecondary: '#6B6258', textTertiary: '#9A9286',
  divider: '#EAE3D9',
  primaryTint: '#FBE9E2', secondaryTint: '#E2EAE6',
  successTint: '#DDEEDF', warningTint: '#F6E7C9',
  success: '#3F8E5C', warning: '#D89B3F', error: '#C24E3F',
  fontDisplay: '"Bricolage Grotesque", ui-rounded, system-ui, sans-serif',
  fontUI: '-apple-system, "SF Pro Text", system-ui, sans-serif',
};

// ───── Buttons ─────────────────────────────────────────────────
function TrotButton({ variant = 'primary', children, onClick, full, icon }) {
  const base = {
    border: 'none', borderRadius: 12, padding: '14px 20px',
    fontFamily: trotTokens.fontUI, fontWeight: 600, fontSize: 17,
    cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
    gap: 8, minHeight: 48, width: full ? '100%' : undefined,
    transition: 'transform 240ms cubic-bezier(0.32,0.72,0,1)',
  };
  const variants = {
    primary: { background: trotTokens.primary, color: '#fff' },
    secondary: { background: trotTokens.secondaryTint, color: trotTokens.secondary },
    plain: { background: 'transparent', color: trotTokens.primary },
    onPhoto: { background: '#fff', color: trotTokens.textPrimary, boxShadow: '0 6px 20px rgba(31,27,22,0.18)' },
  };
  const [pressed, setPressed] = React.useState(false);
  return (
    <button
      onClick={onClick}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      style={{ ...base, ...variants[variant], transform: pressed ? 'scale(0.97)' : 'scale(1)' }}
    >
      {icon ? <i data-lucide={icon} style={{ width: 18, height: 18 }}></i> : null}
      {children}
    </button>
  );
}

// ───── Card ────────────────────────────────────────────────────
function TrotCard({ children, style = {}, padding = 16 }) {
  return (
    <div style={{
      background: trotTokens.elevated, borderRadius: 16, padding,
      boxShadow: '0 1px 2px rgba(31,27,22,0.04), 0 4px 16px rgba(31,27,22,0.06)',
      ...style,
    }}>{children}</div>
  );
}

// ───── Progress ring ───────────────────────────────────────────
function TrotProgressRing({ value = 0.7, size = 96, stroke = 8, color = trotTokens.primary, label, sub }) {
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const offset = circ * (1 - Math.min(value, 1));
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size}>
        <circle cx={size/2} cy={size/2} r={r} stroke={trotTokens.divider} strokeWidth={stroke} fill="none"/>
        <circle cx={size/2} cy={size/2} r={r} stroke={color} strokeWidth={stroke} fill="none"
          strokeLinecap="round" strokeDasharray={circ} strokeDashoffset={offset}
          style={{ transform: 'rotate(-90deg)', transformOrigin: 'center', transition: 'stroke-dashoffset 380ms cubic-bezier(0.34,1.56,0.64,1)' }}/>
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ fontWeight: 700, fontSize: size * 0.26, color: trotTokens.textPrimary, lineHeight: 1 }}>{label}</div>
        {sub ? <div style={{ fontSize: 11, color: trotTokens.textSecondary, marginTop: 2 }}>{sub}</div> : null}
      </div>
    </div>
  );
}

// ───── Streak pill ─────────────────────────────────────────────
function TrotStreak({ days = 14 }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      background: trotTokens.primaryTint, color: '#7A2C16',
      padding: '6px 12px', borderRadius: 9999, fontWeight: 600, fontSize: 13, whiteSpace: 'nowrap',
    }}>
      <i data-lucide="flame" style={{ width: 14, height: 14 }}></i>
      <span>{days}-day streak</span>
    </div>
  );
}

// ───── Walk row ────────────────────────────────────────────────
function TrotWalkRow({ minutes, time, source = 'Passive', confirmed = true }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '14px 0',
      borderBottom: `1px solid ${trotTokens.divider}`,
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 10, background: trotTokens.primaryTint,
        display: 'flex', alignItems: 'center', justifyContent: 'center', color: trotTokens.primary,
      }}>
        <i data-lucide="footprints" style={{ width: 18, height: 18 }}></i>
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 600, fontSize: 15, color: trotTokens.textPrimary }}>
          {minutes}-minute walk
        </div>
        <div style={{ fontSize: 12, color: trotTokens.textSecondary, marginTop: 2 }}>
          {time} · {source}
        </div>
      </div>
      {confirmed ? (
        <span style={{ fontSize: 12, color: trotTokens.success, fontWeight: 600 }}>Confirmed</span>
      ) : (
        <span style={{ fontSize: 12, color: trotTokens.warning, fontWeight: 600 }}>Tap to confirm</span>
      )}
    </div>
  );
}

// ───── Tab bar ─────────────────────────────────────────────────
function TrotTabBar({ active, onChange }) {
  const tabs = [
    { id: 'home', label: 'Today', icon: 'home' },
    { id: 'activity', label: 'Activity', icon: 'calendar' },
    { id: 'insights', label: 'Insights', icon: 'lightbulb' },
    { id: 'profile', label: 'Luna', icon: 'circle-user' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      paddingBottom: 30, paddingTop: 8,
      background: 'rgba(250,247,242,0.92)', backdropFilter: 'blur(20px)',
      WebkitBackdropFilter: 'blur(20px)',
      borderTop: `0.5px solid ${trotTokens.divider}`,
      display: 'flex', justifyContent: 'space-around',
    }}>
      {tabs.map(t => (
        <button key={t.id} onClick={() => onChange(t.id)} style={{
          background: 'none', border: 'none', cursor: 'pointer', padding: '4px 12px',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
          color: active === t.id ? trotTokens.primary : trotTokens.textTertiary,
        }}>
          <i data-lucide={t.icon} style={{ width: 24, height: 24, strokeWidth: active === t.id ? 2.5 : 2 }}></i>
          <span style={{ fontSize: 10, fontWeight: 600 }}>{t.label}</span>
        </button>
      ))}
    </div>
  );
}

Object.assign(window, {
  trotTokens, TrotButton, TrotCard, TrotProgressRing, TrotStreak,
  TrotWalkRow, TrotTabBar,
});
