// macOS window — dark variant, no sidebar
const MAC_FONT = '-apple-system, BlinkMacSystemFont, "SF Pro", "Helvetica Neue", sans-serif';

function MacTrafficLights({ style = {} }) {
  const dot = (bg) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%', background: bg,
      border: '0.5px solid rgba(0,0,0,0.25)',
    }} />
  );
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center', ...style }}>
      {dot('#ff736a')}{dot('#febc2e')}{dot('#19c332')}
    </div>
  );
}

function MacToolbar({ title }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '0 14px', height: 38, flexShrink: 0,
      borderBottom: '0.5px solid rgba(255,255,255,0.06)',
      background: 'linear-gradient(180deg, rgba(255,255,255,0.04) 0%, rgba(255,255,255,0) 100%)',
    }}>
      <MacTrafficLights />
      <div style={{ flex: 1, textAlign: 'center', fontFamily: MAC_FONT,
        fontSize: 13, fontWeight: 600, color: 'rgba(255,255,255,0.85)',
        letterSpacing: 0.2 }}>
        {title}
      </div>
      {/* spacer to balance traffic lights */}
      <div style={{ width: 52 }} />
    </div>
  );
}

function MacWindow({ width = 720, height = 460, title = 'Cylch', children }) {
  return (
    <div style={{
      width, height, borderRadius: 22, overflow: 'hidden',
      background: '#16181d',
      boxShadow:
        '0 0 0 1px rgba(0,0,0,0.6), 0 0 0 0.5px rgba(255,255,255,0.06) inset, 0 24px 60px rgba(0,0,0,0.55)',
      display: 'flex', flexDirection: 'column',
      fontFamily: MAC_FONT,
    }}>
      <MacToolbar title={title} />
      <div style={{ flex: 1, overflow: 'hidden' }}>
        {children}
      </div>
    </div>
  );
}

Object.assign(window, { MacWindow, MacTrafficLights, MacToolbar });
