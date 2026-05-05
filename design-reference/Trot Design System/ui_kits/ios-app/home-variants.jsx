// Trot Home screen — Outdoorsy + Grounded
// Locked as the canonical Home variant in docs/decisions.md (May 2026 grill session).
// Earlier exploration also produced "Warm + joyful" and "Modern + confident" variants;
// both deleted on lock-in. Recover from git history if a future iteration needs them.

function HomeOutdoorsy({ dogName = 'Luna', minutes = 42, target = 60, streak = 14, photo }) {
  const pct = Math.min(minutes / target, 1);
  return (
    <div style={{ background: '#F1EDE4', minHeight: '100%', paddingBottom: 100, boxSizing: 'border-box' }}>
      {/* Full-bleed photo top */}
      <div style={{ width: '100%', height: 280, background: `url(${photo}) center/cover`, position: 'relative' }}>
        <div style={{ position: 'absolute', top: 12, left: 24, right: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ background: 'rgba(255,255,255,0.92)', padding: '6px 12px', borderRadius: 9999, fontSize: 12, fontWeight: 600, color: trotTokens.secondary }}>
            <i data-lucide="flame" style={{ width: 12, height: 12, verticalAlign: -2, marginRight: 4 }}></i>
            {streak} days
          </div>
          <div style={{ background: 'rgba(255,255,255,0.92)', padding: '6px 12px', borderRadius: 9999, fontSize: 12, fontWeight: 600, color: trotTokens.textPrimary }}>
            Tue · 7 May
          </div>
        </div>
      </div>

      {/* Content sits below, no card chrome — just paper */}
      <div style={{ padding: '24px 24px 0' }}>
        <div style={{ fontFamily: trotTokens.fontDisplay, fontSize: 36, fontWeight: 700, color: trotTokens.secondary, lineHeight: 1.05, letterSpacing: '-0.02em' }}>
          {dogName}'s morning.
        </div>
        <div style={{ marginTop: 6, fontSize: 15, color: trotTokens.textSecondary, lineHeight: 1.4 }}>
          {minutes} of {target} minutes done. Beagles do best with a second walk before sundown.
        </div>

        {/* Inline progress bar — no card, just a line */}
        <div style={{ marginTop: 22, height: 8, borderRadius: 9999, background: '#E0D9CA', overflow: 'hidden' }}>
          <div style={{ width: `${pct*100}%`, height: '100%', background: trotTokens.secondary, borderRadius: 9999 }}/>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 12, color: trotTokens.textSecondary }}>
          <span>{Math.round(pct*100)}% of today's needs</span>
          <span>{target - minutes} min to go</span>
        </div>

        {/* Walks as quiet rows on paper */}
        <h2 style={{ marginTop: 32, fontSize: 13, fontWeight: 600, color: trotTokens.textSecondary, textTransform: 'uppercase', letterSpacing: '0.06em' }}>This morning</h2>
        <TrotWalkRow minutes={42} time="7:42 am" source="Passive" confirmed/>

        <div style={{ marginTop: 20 }}>
          <TrotButton variant="secondary" full icon="plus">Log a walk manually</TrotButton>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { HomeOutdoorsy });
