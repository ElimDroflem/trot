// Other Trot screens — Activity, Walk Confirmation, Onboarding

function ActivityScreen({ dogName = 'Luna', photo }) {
  // Build a simple month grid: hit / partial / miss / future
  const days = [];
  for (let i = 1; i <= 31; i++) {
    let s = 'future';
    if (i < 7) s = ['hit','hit','hit','partial','hit','miss','hit'][i-1] || 'hit';
    else if (i < 14) s = ['hit','hit','hit','hit','hit','partial','hit'][i-7];
    else if (i === 14) s = 'today';
    days.push({ day: i, status: s });
  }
  const fillFor = (s) => ({
    hit: trotTokens.primary,
    partial: trotTokens.warning,
    miss: trotTokens.divider,
    today: '#fff',
    future: 'transparent',
  }[s]);
  const borderFor = (s) => ({
    today: `2px solid ${trotTokens.primary}`,
    future: `1px dashed ${trotTokens.divider}`,
  }[s] || 'none');

  return (
    <div style={{ padding: '12px 24px 100px', background: trotTokens.surface, minHeight: '100%', boxSizing: 'border-box' }}>
      <h1 style={{ fontFamily: trotTokens.fontUI, fontSize: 28, fontWeight: 700, margin: 0, color: trotTokens.textPrimary }}>
        Activity
      </h1>
      <div style={{ marginTop: 4, fontSize: 13, color: trotTokens.textSecondary }}>May 2026</div>

      <TrotCard style={{ marginTop: 20 }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 6, fontSize: 11, color: trotTokens.textTertiary, marginBottom: 8, textAlign: 'center', fontWeight: 600 }}>
          {['M','T','W','T','F','S','S'].map((d,i) => <div key={i}>{d}</div>)}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 6 }}>
          {days.map(d => (
            <div key={d.day} style={{
              aspectRatio: '1', borderRadius: 10, background: fillFor(d.status),
              border: borderFor(d.status),
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 12, fontWeight: 600,
              color: d.status === 'hit' ? '#fff' : d.status === 'partial' ? '#705221' : d.status === 'today' ? trotTokens.primary : trotTokens.textTertiary,
            }}>{d.day}</div>
          ))}
        </div>

        <div style={{ display: 'flex', gap: 14, marginTop: 16, fontSize: 12, color: trotTokens.textSecondary, flexWrap: 'wrap' }}>
          <span><span style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 3, background: trotTokens.primary, verticalAlign: -1, marginRight: 4 }}></span>Target hit</span>
          <span><span style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 3, background: trotTokens.warning, verticalAlign: -1, marginRight: 4 }}></span>Partial</span>
          <span><span style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 3, background: trotTokens.divider, verticalAlign: -1, marginRight: 4 }}></span>Missed</span>
        </div>
      </TrotCard>

      <h2 style={{ marginTop: 24, fontSize: 13, fontWeight: 600, color: trotTokens.textSecondary, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
        Recent walks
      </h2>
      <TrotCard style={{ marginTop: 8 }}>
        <TrotWalkRow minutes={42} time="Today, 7:42 am" source="Passive" confirmed/>
        <TrotWalkRow minutes={28} time="Yesterday, 6:15 pm" source="Manual" confirmed/>
        <TrotWalkRow minutes={35} time="Yesterday, 7:50 am" source="Passive" confirmed/>
        <TrotWalkRow minutes={22} time="Sunday, 8:10 am" source="Passive" confirmed={false}/>
      </TrotCard>
    </div>
  );
}

function WalkConfirmation({ dogName = 'Luna', minutes = 28, photo, onConfirm, onDismiss }) {
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(31,27,22,0.45)', display: 'flex', alignItems: 'flex-end' }}>
      <div style={{
        width: '100%', background: trotTokens.elevated, borderTopLeftRadius: 24, borderTopRightRadius: 24,
        padding: '20px 24px 36px', boxShadow: '0 -12px 48px rgba(31,27,22,0.18)',
      }}>
        <div style={{ width: 36, height: 5, borderRadius: 9999, background: trotTokens.divider, margin: '0 auto 18px' }}/>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 64, height: 64, borderRadius: 9999, background: `url(${photo}) center/cover`, flex: 'none' }}/>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, color: trotTokens.textSecondary, fontWeight: 500 }}>Walk detected · just now</div>
            <div style={{ fontSize: 20, fontWeight: 700, color: trotTokens.textPrimary, marginTop: 2 }}>
              {minutes}-minute walk.
            </div>
          </div>
        </div>
        <p style={{ marginTop: 14, fontSize: 15, color: trotTokens.textSecondary, lineHeight: 1.45 }}>
          Was that with {dogName}?
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 18 }}>
          <TrotButton variant="secondary" onClick={onDismiss}>Not this time</TrotButton>
          <TrotButton variant="primary" onClick={onConfirm}>Yes, log it</TrotButton>
        </div>
      </div>
    </div>
  );
}

function OnboardingDog({ onNext }) {
  const [name, setName] = React.useState('Luna');
  return (
    <div style={{ padding: '40px 24px 100px', background: trotTokens.surface, minHeight: '100%', boxSizing: 'border-box' }}>
      <div style={{ fontSize: 13, color: trotTokens.textSecondary, fontWeight: 600 }}>Step 1 of 4</div>
      <h1 style={{ fontFamily: trotTokens.fontDisplay, fontSize: 36, fontWeight: 700, margin: '8px 0 0', color: trotTokens.textPrimary, letterSpacing: '-0.02em', lineHeight: 1.1 }}>
        Tell us about your dog.
      </h1>
      <p style={{ marginTop: 10, fontSize: 15, color: trotTokens.textSecondary, lineHeight: 1.4 }}>
        Trot tailors targets to breed, age, and health. We start with a vetted base table and refine from there.
      </p>

      <div style={{ marginTop: 28 }}>
        <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>Name</label>
        <input value={name} onChange={e => setName(e.target.value)} style={{
          width: '100%', boxSizing: 'border-box', padding: '14px 16px',
          border: `1px solid ${trotTokens.divider}`, borderRadius: 12, fontSize: 17,
          background: 'white', color: trotTokens.textPrimary, fontFamily: trotTokens.fontUI,
        }}/>
      </div>

      <div style={{ marginTop: 18 }}>
        <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>Breed</label>
        <div style={{
          padding: '14px 16px', border: `1px solid ${trotTokens.divider}`, borderRadius: 12,
          fontSize: 17, color: trotTokens.textPrimary, background: 'white',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>Beagle <i data-lucide="chevron-right" style={{ width: 18, height: 18, color: trotTokens.textTertiary }}></i></div>
      </div>

      <div style={{ marginTop: 32 }}>
        <TrotButton variant="primary" full onClick={onNext}>Continue</TrotButton>
      </div>
    </div>
  );
}

Object.assign(window, { ActivityScreen, WalkConfirmation, OnboardingDog });
