// Cylch — Adalight rainbow controller (dark, minimal)

const FONT = '-apple-system, BlinkMacSystemFont, "SF Pro", "Helvetica Neue", sans-serif';
const MONO = '"JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace';

const TAU = Math.PI * 2;

function hsl(h, s, l) {
  h = ((h % 1) + 1) % 1;
  const a = s * Math.min(l, 1 - l);
  const f = (n) => {
    const k = (n + h * 12) % 12;
    return l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1));
  };
  return [Math.round(f(0) * 255), Math.round(f(8) * 255), Math.round(f(4) * 255)];
}

function rgbToCss([r, g, b]) {
  return `rgb(${r | 0},${g | 0},${b | 0})`;
}

function useAnimationFrame(active = true) {
  const [t, setT] = React.useState(0);
  React.useEffect(() => {
    if (!active) return;
    let raf, start = performance.now();
    const tick = (now) => {
      setT(now - start);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [active]);
  return t;
}

// ─────────────────────────────────────────────────────────────────────────────
// LED row — single line of circles across the top
// ─────────────────────────────────────────────────────────────────────────────
function LEDRow({ count, speed, brightness, connected }) {
  const t = useAnimationFrame(connected);
  const b = brightness / 100;

  const dots = [];
  for (let i = 0; i < count; i++) {
    const c = hsl(i / count - t * speed * 0.0004, 1, 0.55);
    dots.push([c[0] * b, c[1] * b, c[2] * b]);
  }

  return (
    <div
      style={{
        display: 'flex',
        gap: 8,
        alignItems: 'center',
        justifyContent: 'center',
        padding: '22px 18px',
        borderRadius: 14,
        background:
          'radial-gradient(ellipse at 50% 30%, rgba(255,255,255,0.04) 0%, rgba(255,255,255,0) 70%), #0d0e12',
        border: '0.5px solid rgba(255,255,255,0.06)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.05)',
        flexShrink: 0,
        overflow: 'hidden',
      }}
    >
      {dots.map((c, i) => (
        <LED key={i} rgb={c} dim={!connected} />
      ))}
    </div>
  );
}

function LED({ rgb, dim }) {
  const css = rgbToCss(rgb);
  const lum = (rgb[0] + rgb[1] + rgb[2]) / 3 / 255;
  const size = 16;
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <div
        style={{
          position: 'absolute',
          inset: -size,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${css} 0%, transparent 60%)`,
          opacity: dim ? 0 : 0.55 * lum + 0.1,
          filter: 'blur(4px)',
          pointerEvents: 'none',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '50%',
          background: dim ? '#1a1c22' : css,
          boxShadow: dim
            ? 'inset 0 1px 1px rgba(255,255,255,0.04)'
            : `inset 0 -1px 2px rgba(0,0,0,0.5), inset 0 1px 1px rgba(255,255,255,${0.25 + lum * 0.4}), 0 0 ${4 + lum * 14}px ${css}`,
        }}
      />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient sliders — track is the metaphor
// ─────────────────────────────────────────────────────────────────────────────
function GradientSlider({ label, value, onChange, min = 0, max = 100, unit = '', gradient }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10, flex: 1 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <span
          style={{
            fontFamily: MONO,
            fontSize: 10,
            letterSpacing: 0.8,
            textTransform: 'uppercase',
            color: 'rgba(255,255,255,0.5)',
          }}
        >
          {label}
        </span>
        <span
          style={{
            fontFamily: MONO,
            fontSize: 12,
            color: 'rgba(255,255,255,0.92)',
            fontVariantNumeric: 'tabular-nums',
          }}
        >
          {value}
          {unit}
        </span>
      </div>
      <div style={{ position: 'relative', height: 24, display: 'flex', alignItems: 'center' }}>
        {/* gradient track */}
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            height: 8,
            borderRadius: 4,
            background: gradient,
            boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.6), 0 0 0 0.5px rgba(255,255,255,0.08)',
          }}
        />
        {/* dim portion to the right of thumb */}
        <div
          style={{
            position: 'absolute',
            left: `${pct}%`,
            right: 0,
            height: 8,
            borderRadius: 4,
            background: 'rgba(0,0,0,0.55)',
            pointerEvents: 'none',
          }}
        />
        {/* thumb */}
        <div
          style={{
            position: 'absolute',
            left: `calc(${pct}% - 9px)`,
            width: 18,
            height: 18,
            borderRadius: '50%',
            background: '#fff',
            boxShadow:
              '0 1px 3px rgba(0,0,0,0.5), 0 0 0 0.5px rgba(0,0,0,0.4), inset 0 -1px 1px rgba(0,0,0,0.1)',
          }}
        />
        <input
          type="range"
          min={min}
          max={max}
          value={value}
          onChange={(e) => onChange(+e.target.value)}
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            opacity: 0,
            cursor: 'pointer',
            margin: 0,
          }}
        />
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Field + dark Select (port chooser)
// ─────────────────────────────────────────────────────────────────────────────
function Field({ label, children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 7, minWidth: 0 }}>
      <span
        style={{
          fontFamily: MONO,
          fontSize: 10,
          letterSpacing: 0.8,
          textTransform: 'uppercase',
          color: 'rgba(255,255,255,0.5)',
        }}
      >
        {label}
      </span>
      {children}
    </div>
  );
}

function Select({ value, onChange, options, width = 240 }) {
  return (
    <div
      style={{
        position: 'relative',
        width,
        height: 32,
        display: 'flex',
        alignItems: 'center',
        background: 'rgba(255,255,255,0.05)',
        border: '0.5px solid rgba(255,255,255,0.1)',
        borderRadius: 8,
        padding: '0 30px 0 12px',
        fontFamily: MONO,
        fontSize: 12,
        color: 'rgba(255,255,255,0.92)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.03)',
      }}
    >
      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {value}
      </span>
      <svg
        width="9"
        height="9"
        viewBox="0 0 9 9"
        style={{ position: 'absolute', right: 11, top: '50%', marginTop: -4, opacity: 0.55 }}
      >
        <path d="M1 2.5l3.5 4 3.5-4" stroke="#fff" strokeWidth="1.2" fill="none" strokeLinecap="round" />
      </svg>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer' }}
      >
        {options.map((o) => (
          <option key={o} value={o} style={{ color: '#000' }}>
            {o}
          </option>
        ))}
      </select>
    </div>
  );
}

function ConnectButton({ connected, onToggle }) {
  return (
    <button
      onClick={onToggle}
      style={{
        height: 32,
        padding: '0 16px',
        border: 'none',
        borderRadius: 8,
        background: connected
          ? 'linear-gradient(180deg, #ff5b5b 0%, #d63838 100%)'
          : 'linear-gradient(180deg, #3ed47a 0%, #1fa84e 100%)',
        color: '#fff',
        fontFamily: FONT,
        fontSize: 12,
        fontWeight: 600,
        letterSpacing: 0.2,
        cursor: 'pointer',
        boxShadow:
          '0 1px 2px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.25), inset 0 -1px 0 rgba(0,0,0,0.2)',
        display: 'flex',
        alignItems: 'center',
        gap: 8,
      }}
    >
      <span
        style={{
          width: 6,
          height: 6,
          borderRadius: '50%',
          background: '#fff',
          boxShadow: connected ? '0 0 6px #fff' : 'none',
        }}
      />
      {connected ? 'Disconnect' : 'Connect'}
    </button>
  );
}

function NumberInput({ value, onChange, min = 1, max = 300 }) {
  const clamp = (v) => Math.max(min, Math.min(max, v | 0));
  const step = (d) => onChange(clamp(value + d));
  const btn = (label, fn) => (
    <button onClick={fn} style={{
      width: 22, height: 22, border: 'none', borderRadius: 5,
      background: 'rgba(255,255,255,0.06)', color: 'rgba(255,255,255,0.78)',
      fontFamily: FONT, fontSize: 13, cursor: 'pointer', lineHeight: 1, padding: 0,
    }}>{label}</button>
  );
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      background: 'rgba(255,255,255,0.05)',
      border: '0.5px solid rgba(255,255,255,0.1)',
      borderRadius: 8, padding: '4px 5px', height: 32, width: 96,
      boxSizing: 'border-box',
      boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.03)',
    }}>
      {btn('−', () => step(-1))}
      <input
        type="number"
        value={value}
        min={min}
        max={max}
        onChange={(e) => onChange(clamp(+e.target.value || min))}
        style={{
          flex: 1, width: 0, background: 'transparent', border: 'none', outline: 'none',
          color: 'rgba(255,255,255,0.95)', fontFamily: MONO, fontSize: 13, fontWeight: 500,
          textAlign: 'center', fontVariantNumeric: 'tabular-nums', padding: 0,
          MozAppearance: 'textfield',
        }}
      />
      {btn('+', () => step(1))}
    </div>
  );
}

Object.assign(window, {
  LEDRow,
  GradientSlider,
  Field,
  Select,
  ConnectButton,
  NumberInput,
  FONT,
  MONO,
});
