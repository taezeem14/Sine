/* ==========================================================================
   SINE — Interactive Website Controller (Vanilla ES6, Zero Dependencies)
   - Subtle 60fps acoustic sine-wave canvas (respects prefers-reduced-motion)
   - Live interactive Android Phone showcase (CoverPalette aurora, lyrics, miniplayer)
   - Real interactive 6-Band Bezier Hardware EQ + 5-Band Log-Frequency Interpolator
   - Clipboard toast, mobile drawer, scroll reveal & GitHub stars hydration
   ========================================================================== */

(() => {
  'use strict';

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ------------------------------------------------------------------------
     1. TOAST & CLIPBOARD HELPERS
     ------------------------------------------------------------------------ */
  const toastEl = document.getElementById('toast');
  let toastTimer = null;

  function showToast(message) {
    if (!toastEl) return;
    toastEl.textContent = message;
    toastEl.classList.add('is-visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('is-visible'), 2200);
  }

  document.querySelectorAll('[data-copy]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const text = btn.getAttribute('data-copy');
      const label = btn.getAttribute('data-copy-label') || 'Copied to clipboard';
      if (!text) return;
      try {
        await navigator.clipboard.writeText(text);
        showToast(label);
      } catch (_) {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        showToast(label);
      }
    });
  });

  /* ------------------------------------------------------------------------
     2. MOBILE NAVIGATION DRAWER
     ------------------------------------------------------------------------ */
  const menuBtn = document.getElementById('menuToggle');
  const mobileDrawer = document.getElementById('mobileDrawer');

  if (menuBtn && mobileDrawer) {
    const closeDrawer = () => {
      mobileDrawer.classList.remove('is-open');
      menuBtn.setAttribute('aria-expanded', 'false');
    };

    menuBtn.addEventListener('click', () => {
      const open = mobileDrawer.classList.toggle('is-open');
      menuBtn.setAttribute('aria-expanded', String(open));
    });

    mobileDrawer.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', closeDrawer);
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') closeDrawer();
    });
  }

  /* ------------------------------------------------------------------------
     3. CALM ACOUSTIC SINE WAVE HERO CANVAS
     ------------------------------------------------------------------------ */
  const waveCanvas = document.getElementById('heroWaveCanvas');
  if (waveCanvas && !prefersReducedMotion) {
    const ctx = waveCanvas.getContext('2d');
    let width = 0;
    let height = 0;
    let phase = 0;
    let rafId = null;

    const resizeWave = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = waveCanvas.getBoundingClientRect();
      width = rect.width;
      height = rect.height;
      waveCanvas.width = Math.round(width * dpr);
      waveCanvas.height = Math.round(height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    const drawWave = () => {
      ctx.clearRect(0, 0, width, height);
      const midY = height * 0.52;
      const lines = [
        { amp: 26, freq: 0.0042, speed: 0.009, alpha: 0.16, color: '41, 121, 255', width: 1.4 },
        { amp: 18, freq: 0.0061, speed: 0.013, alpha: 0.10, color: '56, 189, 248', width: 1.0 },
        { amp: 34, freq: 0.0029, speed: 0.006, alpha: 0.07, color: '148, 163, 184', width: 1.0 },
      ];

      for (const line of lines) {
        ctx.beginPath();
        for (let x = 0; x <= width; x += 6) {
          const envelope = Math.sin((x / width) * Math.PI);
          const y = midY + Math.sin(x * line.freq + phase * (line.speed / 0.009)) * line.amp * envelope;
          if (x === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.strokeStyle = `rgba(${line.color}, ${line.alpha})`;
        ctx.lineWidth = line.width;
        ctx.stroke();
      }

      phase += 0.012;
      rafId = requestAnimationFrame(drawWave);
    };

    resizeWave();
    window.addEventListener('resize', resizeWave, { passive: true });
    document.addEventListener('visibilitychange', () => {
      if (document.hidden && rafId) {
        cancelAnimationFrame(rafId);
        rafId = null;
      } else if (!document.hidden && !rafId) {
        rafId = requestAnimationFrame(drawWave);
      }
    });
    rafId = requestAnimationFrame(drawWave);
  }

  /* ------------------------------------------------------------------------
     4. INTERACTIVE ANDROID PHONE SHOWCASE
     ------------------------------------------------------------------------ */
  const showcaseTabs = document.querySelectorAll('.showcase-tab');
  const phoneViews = document.querySelectorAll('.phone-view');
  const phoneScreen = document.getElementById('phoneScreen');

  showcaseTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const target = tab.getAttribute('data-view');
      showcaseTabs.forEach((t) => {
        const active = t === tab;
        t.classList.toggle('is-active', active);
        t.setAttribute('aria-selected', String(active));
      });
      phoneViews.forEach((view) => {
        view.classList.toggle('is-active', view.id === `view-${target}`);
      });
    });
  });

  // Live CoverPalette Presets inside Phone Mockup (mirrors v1.4.1/v1.4.2 perceptual quantizer)
  const coverTracks = {
    cobalt: {
      title: 'Midnight Telemetry',
      artist: 'Daft Signal · Opus 160 kbps',
      coverBg: 'linear-gradient(145deg, #1d4ed8 0%, #0f172a 62%, #0284c7 100%)',
      dom: 'rgba(41, 121, 255, 0.56)',
      sec: 'rgba(56, 189, 248, 0.44)',
      acc: 'rgba(99, 102, 241, 0.34)',
      vinyl: '#2979ff',
      caption: 'BLUE + CYAN · QUANTIZED',
    },
    crimson: {
      title: 'Afterglow Static',
      artist: 'Nocturne Labs · Opus 160 kbps',
      coverBg: 'linear-gradient(145deg, #b91c1c 0%, #2a0a12 64%, #d97706 100%)',
      dom: 'rgba(220, 38, 38, 0.56)',
      sec: 'rgba(245, 158, 11, 0.40)',
      acc: 'rgba(244, 63, 94, 0.32)',
      vinyl: '#dc2626',
      caption: 'CRIMSON + AMBER · QUANTIZED',
    },
    noir: {
      title: 'Monochrome Study IV',
      artist: 'Klara Vance · AAC 128 kbps',
      coverBg: 'linear-gradient(145deg, #4b5563 0%, #111318 65%, #9ca3af 100%)',
      dom: 'rgba(156, 163, 175, 0.36)',
      sec: 'rgba(100, 116, 139, 0.30)',
      acc: 'rgba(203, 213, 225, 0.22)',
      vinyl: '#64748b',
      caption: 'MONOCHROME · ZERO FAKE HUE',
    },
  };

  const npCover = document.getElementById('npCover');
  const npTitle = document.getElementById('npTrackTitle');
  const npArtist = document.getElementById('npTrackArtist');
  const npCaption = document.getElementById('npCoverCaption');
  const npVinyl = document.getElementById('npVinyl');
  const npPlayBtn = document.getElementById('npPlayBtn');
  const npScrubFill = document.getElementById('npScrubFill');
  const npElapsed = document.getElementById('npElapsed');

  let phonePlaying = true;
  let elapsedSec = 82;
  const totalSec = 218;

  function formatTime(sec) {
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${String(s).padStart(2, '0')}`;
  }

  function applyCoverTrack(key) {
    const t = coverTracks[key];
    if (!t || !phoneScreen) return;
    phoneScreen.style.setProperty('--cover-dom', t.dom);
    phoneScreen.style.setProperty('--cover-sec', t.sec);
    phoneScreen.style.setProperty('--cover-acc', t.acc);
    phoneScreen.style.setProperty('--vinyl-label', t.vinyl);
    if (npCover) npCover.style.background = t.coverBg;
    if (npTitle) npTitle.textContent = t.title;
    if (npArtist) npArtist.textContent = t.artist;
    if (npCaption) npCaption.textContent = t.caption;

    document.querySelectorAll('.palette-chip').forEach((chip) => {
      chip.classList.toggle('is-selected', chip.getAttribute('data-palette') === key);
    });
  }

  document.querySelectorAll('.palette-chip').forEach((chip) => {
    chip.addEventListener('click', () => applyCoverTrack(chip.getAttribute('data-palette')));
  });
  applyCoverTrack('cobalt');

  if (npPlayBtn) {
    npPlayBtn.addEventListener('click', () => {
      phonePlaying = !phonePlaying;
      if (npVinyl) npVinyl.classList.toggle('is-paused', !phonePlaying);
      npPlayBtn.setAttribute('aria-label', phonePlaying ? 'Pause preview' : 'Play preview');
      npPlayBtn.innerHTML = phonePlaying
        ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></svg>'
        : '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><polygon points="6,4 20,12 6,20"/></svg>';
    });
  }

  // Gentle live scrubber + karaoke sweep inside phone preview
  const karaokeWord = document.getElementById('karaokeWord');
  let karaokePct = 20;
  setInterval(() => {
    if (!phonePlaying) return;
    elapsedSec = (elapsedSec + 1) % totalSec;
    if (npScrubFill) npScrubFill.style.width = `${((elapsedSec / totalSec) * 100).toFixed(1)}%`;
    if (npElapsed) npElapsed.textContent = formatTime(elapsedSec);
  }, 1000);

  if (!prefersReducedMotion && karaokeWord) {
    setInterval(() => {
      if (!phonePlaying) return;
      karaokePct = (karaokePct + 3) % 104;
      karaokeWord.style.setProperty('--sweep', `${Math.min(100, karaokePct)}%`);
    }, 90);
  }

  // Interactive MiniPlayer Swipe-Down Simulation button
  const miniDemoBar = document.getElementById('phoneMiniPlayer');
  const miniDismissBtn = document.getElementById('miniDismissTestBtn');
  if (miniDemoBar && miniDismissBtn) {
    miniDismissBtn.addEventListener('click', () => {
      miniDemoBar.classList.add('is-dismissed');
      showToast('Playback stopped & MiniPlayer dismissed');
      setTimeout(() => miniDemoBar.classList.remove('is-dismissed'), 1400);
    });
  }

  /* ------------------------------------------------------------------------
     5. INTERACTIVE 6-BAND HARDWARE EQUALIZER LAB
     Exact v1.4.2 Log-Frequency 6->5 Hardware Interpolation + Headroom Model
     ------------------------------------------------------------------------ */
  const eqCanvas = document.getElementById('eqCanvas');
  if (eqCanvas) {
    const ctx = eqCanvas.getContext('2d');
    const uiFreqs = [60, 150, 400, 1000, 2400, 15000];
    const hwFreqs = [60, 230, 910, 3600, 14000];

    const presets = {
      Flat: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      'Bass Boost': [6.0, 4.5, 1.5, 0.0, 0.5, 1.0],
      'Vocal Booster': [-1.5, -0.5, 3.5, 5.0, 3.5, 1.5],
      Electronic: [5.0, 3.0, 0.5, 1.0, 4.0, 5.5],
      Rock: [4.5, 2.5, -1.0, 1.5, 3.5, 4.5],
      Acoustic: [2.5, 1.5, 2.0, 1.5, 2.5, 3.0],
      Jazz: [2.0, 1.0, 2.5, 2.0, 1.5, 2.5],
      'Late Night': [3.0, 2.0, 0.5, -1.0, -2.0, -3.0],
    };

    let gains = [...presets['Bass Boost']];
    let activePreset = 'Bass Boost';
    let eqEnabled = true;
    let bassBoost = 0.25;
    let activeDragBand = null;
    let lastTapBand = null;
    let lastTapTime = 0;

    const eqSwitch = document.getElementById('eqPowerSwitch');
    const eqStateLabel = document.getElementById('eqStateLabel');
    const bassSlider = document.getElementById('bassBoostSlider');
    const bassOutput = document.getElementById('bassBoostOutput');
    const headroomOut = document.getElementById('headroomReadout');
    const activePresetOut = document.getElementById('activePresetReadout');
    const hwValueEls = hwFreqs.map((_, i) => document.getElementById(`hwBand${i}`));

    // Exact log-frequency linear interpolation from SineAudioHandler.interpolateSixBandGain()
    function interpolateSixBandGain(centerFreqHz, sixGains) {
      const freq = Math.max(20, Math.min(20000, centerFreqHz));
      if (freq <= uiFreqs[0]) return sixGains[0];
      if (freq >= uiFreqs[uiFreqs.length - 1]) return sixGains[sixGains.length - 1];
      const logF = Math.log(freq);
      for (let i = 0; i < uiFreqs.length - 1; i++) {
        if (freq >= uiFreqs[i] && freq <= uiFreqs[i + 1]) {
          const t = (logF - Math.log(uiFreqs[i])) / (Math.log(uiFreqs[i + 1]) - Math.log(uiFreqs[i]));
          return sixGains[i] + (sixGains[i + 1] - sixGains[i]) * t;
        }
      }
      return sixGains[sixGains.length - 1];
    }

    function updateTelemetry() {
      const bassAdd = bassBoost * 9.0;
      const lowMidAdd = bassBoost * 4.5;

      hwFreqs.forEach((f, idx) => {
        let g = eqEnabled ? interpolateSixBandGain(f, gains) : 0;
        if (eqEnabled && idx === 0) g += bassAdd;
        if (eqEnabled && idx === 1) g += lowMidAdd;
        g = Math.max(-15, Math.min(15, g));
        if (hwValueEls[idx]) {
          hwValueEls[idx].textContent = `${g > 0 ? '+' : ''}${g.toFixed(1)} dB`;
          hwValueEls[idx].style.color = !eqEnabled
            ? '#646d80'
            : g > 0.2
            ? '#569dff'
            : g < -0.2
            ? '#fbbf24'
            : '#f4f6fa';
        }
      });

      let maxBoost = 0;
      if (eqEnabled) {
        maxBoost = Math.max(0, ...gains) + bassBoost * 4.5;
      }
      let attenDb = 0;
      if (maxBoost > 1.5) {
        attenDb = Math.min(2.8, Math.max(0, (maxBoost - 1.5) * 0.26));
      }
      if (headroomOut) {
        headroomOut.textContent = eqEnabled ? `-${attenDb.toFixed(2)} dB (Anti-Clip)` : '0.00 dB (Bypass)';
      }
      if (activePresetOut) {
        activePresetOut.textContent = eqEnabled ? activePreset : 'Bypassed';
      }
    }

    function getCanvasMetrics() {
      const rect = eqCanvas.getBoundingClientRect();
      const padX = 28;
      const padY = 26;
      return {
        w: rect.width,
        h: rect.height,
        padX,
        padY,
        usableW: rect.width - padX * 2,
        usableH: rect.height - padY * 2,
      };
    }

    function drawEq() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const m = getCanvasMetrics();
      eqCanvas.width = Math.round(m.w * dpr);
      eqCanvas.height = Math.round(m.h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, m.w, m.h);

      const colW = m.usableW / 5;

      // Vertical frequency gridlines
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
      ctx.lineWidth = 1;
      for (let i = 0; i < 6; i++) {
        const x = m.padX + i * colW;
        ctx.beginPath();
        ctx.moveTo(x, m.padY - 4);
        ctx.lineTo(x, m.h - m.padY + 6);
        ctx.stroke();
      }

      // 0 dB unity centerline
      const zeroY = m.padY + m.usableH / 2;
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.11)';
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(m.padX - 8, zeroY);
      ctx.lineTo(m.w - m.padX + 8, zeroY);
      ctx.stroke();
      ctx.setLineDash([]);

      // +12 / 0 / -12 subtle labels
      ctx.fillStyle = 'rgba(154, 163, 181, 0.45)';
      ctx.font = '500 10px "JetBrains Mono", monospace';
      ctx.fillText('+12', 2, m.padY + 3);
      ctx.fillText('0 dB', 2, zeroY + 3);
      ctx.fillText('-12', 2, m.h - m.padY + 3);

      // Compute band coordinates
      const pts = gains.map((g, i) => {
        const x = m.padX + i * colW;
        const norm = (Math.max(-12, Math.min(12, g)) + 12) / 24;
        const y = m.h - m.padY - norm * m.usableH;
        return { x, y };
      });

      const strokeHex = eqEnabled ? '#2979ff' : 'rgba(255, 255, 255, 0.28)';

      // Smooth cubic Bezier path
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let i = 0; i < pts.length - 1; i++) {
        const p0 = pts[i];
        const p1 = pts[i + 1];
        const midX = p0.x + (p1.x - p0.x) / 2;
        ctx.bezierCurveTo(midX, p0.y, midX, p1.y, p1.x, p1.y);
      }

      // Fill area under curve
      const grad = ctx.createLinearGradient(0, m.padY, 0, m.h - m.padY);
      if (eqEnabled) {
        grad.addColorStop(0, 'rgba(41, 121, 255, 0.34)');
        grad.addColorStop(0.65, 'rgba(41, 121, 255, 0.08)');
        grad.addColorStop(1, 'rgba(41, 121, 255, 0.0)');
      } else {
        grad.addColorStop(0, 'rgba(255, 255, 255, 0.08)');
        grad.addColorStop(1, 'rgba(255, 255, 255, 0.0)');
      }

      ctx.save();
      ctx.lineTo(pts[pts.length - 1].x, m.h - m.padY + 6);
      ctx.lineTo(pts[0].x, m.h - m.padY + 6);
      ctx.closePath();
      ctx.fillStyle = grad;
      ctx.fill();
      ctx.restore();

      // Stroke Bezier spline
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let i = 0; i < pts.length - 1; i++) {
        const p0 = pts[i];
        const p1 = pts[i + 1];
        const midX = p0.x + (p1.x - p0.x) / 2;
        ctx.bezierCurveTo(midX, p0.y, midX, p1.y, p1.x, p1.y);
      }
      ctx.strokeStyle = strokeHex;
      ctx.lineWidth = 2.8;
      ctx.lineCap = 'round';
      ctx.stroke();

      // Draw draggable knobs
      pts.forEach((pt, i) => {
        const dragged = activeDragBand === i;
        if (dragged) {
          const halo = ctx.createRadialGradient(pt.x, pt.y, 4, pt.x, pt.y, 20);
          halo.addColorStop(0, 'rgba(41, 121, 255, 0.45)');
          halo.addColorStop(1, 'rgba(41, 121, 255, 0)');
          ctx.fillStyle = halo;
          ctx.beginPath();
          ctx.arc(pt.x, pt.y, 20, 0, Math.PI * 2);
          ctx.fill();
        }

        ctx.beginPath();
        ctx.arc(pt.x, pt.y, dragged ? 9.5 : 7.5, 0, Math.PI * 2);
        ctx.fillStyle = eqEnabled ? '#ffffff' : 'rgba(255, 255, 255, 0.45)';
        ctx.fill();

        ctx.beginPath();
        ctx.arc(pt.x, pt.y, dragged ? 4 : 3, 0, Math.PI * 2);
        ctx.fillStyle = eqEnabled ? '#2979ff' : '#334155';
        ctx.fill();

        if (dragged) {
          const gVal = gains[i];
          const text = `${gVal > 0 ? '+' : ''}${gVal.toFixed(1)} dB`;
          ctx.font = '600 10.5px "JetBrains Mono", monospace';
          const tw = ctx.measureText(text).width;
          const bx = Math.max(8, Math.min(m.w - tw - 20, pt.x - tw / 2 - 7));
          const by = Math.max(4, pt.y - 34);
          ctx.fillStyle = '#141822';
          ctx.strokeStyle = '#2979ff';
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.roundRect(bx, by, tw + 14, 20, 6);
          ctx.fill();
          ctx.stroke();
          ctx.fillStyle = '#ffffff';
          ctx.fillText(text, bx + 7, by + 13.5);
        }
      });

      updateTelemetry();
    }

    function setPresetUI(name) {
      activePreset = name;
      document.querySelectorAll('.preset-btn').forEach((btn) => {
        btn.classList.toggle('is-active', btn.getAttribute('data-preset') === name);
      });
    }

    function updateBandFromPointer(bandIdx, clientY) {
      const rect = eqCanvas.getBoundingClientRect();
      const padY = 26;
      const usableH = rect.height - padY * 2;
      const y = Math.max(0, Math.min(usableH, clientY - rect.top - padY));
      const norm = 1 - y / usableH;
      const raw = norm * 24 - 12;
      gains[bandIdx] = Math.round(raw * 10) / 10;
      if (!eqEnabled) {
        eqEnabled = true;
        if (eqSwitch) eqSwitch.setAttribute('aria-checked', 'true');
        if (eqStateLabel) eqStateLabel.textContent = 'Hardware DSP Active';
      }
      setPresetUI('Custom');
      drawEq();
    }

    eqCanvas.addEventListener('pointerdown', (e) => {
      eqCanvas.setPointerCapture(e.pointerId);
      const rect = eqCanvas.getBoundingClientRect();
      const padX = 28;
      const usableW = rect.width - padX * 2;
      const relX = Math.max(0, Math.min(usableW, e.clientX - rect.left - padX));
      const bandIdx = Math.max(0, Math.min(5, Math.round(relX / (usableW / 5))));
      activeDragBand = bandIdx;

      const now = Date.now();
      if (lastTapBand === bandIdx && now - lastTapTime < 280) {
        gains[bandIdx] = 0.0;
        lastTapBand = null;
        setPresetUI('Custom');
        drawEq();
        return;
      }
      lastTapBand = bandIdx;
      lastTapTime = now;

      updateBandFromPointer(bandIdx, e.clientY);
    });

    eqCanvas.addEventListener('pointermove', (e) => {
      if (activeDragBand === null) return;
      lastTapBand = null; // Never trigger double-tap while dragging!
      updateBandFromPointer(activeDragBand, e.clientY);
    });

    const endDrag = () => {
      if (activeDragBand !== null) {
        activeDragBand = null;
        drawEq();
      }
    };
    eqCanvas.addEventListener('pointerup', endDrag);
    eqCanvas.addEventListener('pointercancel', endDrag);

    document.querySelectorAll('.preset-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        const name = btn.getAttribute('data-preset');
        if (!name || !presets[name]) return;
        gains = [...presets[name]];
        if (!eqEnabled) {
          eqEnabled = true;
          if (eqSwitch) eqSwitch.setAttribute('aria-checked', 'true');
          if (eqStateLabel) eqStateLabel.textContent = 'Hardware DSP Active';
        }
        setPresetUI(name);
        drawEq();
      });
    });

    if (eqSwitch) {
      eqSwitch.addEventListener('click', () => {
        eqEnabled = !eqEnabled;
        eqSwitch.setAttribute('aria-checked', String(eqEnabled));
        if (eqStateLabel) {
          eqStateLabel.textContent = eqEnabled ? 'Hardware DSP Active' : 'Bypassed';
        }
        drawEq();
      });
    }

    if (bassSlider && bassOutput) {
      bassSlider.addEventListener('input', () => {
        bassBoost = Number(bassSlider.value) / 100;
        bassOutput.textContent = `${Math.round(bassBoost * 100)}%`;
        if (bassBoost > 0 && !eqEnabled) {
          eqEnabled = true;
          if (eqSwitch) eqSwitch.setAttribute('aria-checked', 'true');
          if (eqStateLabel) eqStateLabel.textContent = 'Hardware DSP Active';
        }
        updateTelemetry();
      });
    }

    window.addEventListener('resize', drawEq, { passive: true });
    drawEq();
  }

  /* ------------------------------------------------------------------------
     6. SUBTLE SCROLL REVEAL & OPTIONAL GITHUB STARS HYDRATION
     ------------------------------------------------------------------------ */
  if (!prefersReducedMotion && 'IntersectionObserver' in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-in');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: '0px 0px -30px 0px' }
    );
    document.querySelectorAll('.reveal').forEach((el) => observer.observe(el));
  } else {
    document.querySelectorAll('.reveal').forEach((el) => el.classList.add('is-in'));
  }

  // Silently hydrate GitHub star count (gracefully skipped if offline or rate-limited)
  const starsEl = document.getElementById('ghStars');
  if (starsEl && window.fetch) {
    fetch('https://api.github.com/repos/taezeem14/Sine')
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (data && typeof data.stargazers_count === 'number' && data.stargazers_count > 0) {
          starsEl.textContent = String(data.stargazers_count);
          starsEl.hidden = false;
        }
      })
      .catch(() => {});
  }
})();
