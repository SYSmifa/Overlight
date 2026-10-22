/* ---------- AdMob (Android app): consent (UMP), interstitial and rewarded behind a Playgama-Bridge-shaped shim ----------
   AM.shim is null outside the app (browser / Playgama); in the app ADS.bridge() hands it out, so ADS keeps one code path.
   TESTING = true asks for test ads only (the ad unit ids are the real ones); set it to false for the Play Store build. */
const AM = (() => {
  const TESTING = true;
  const IDS = { inter: 'ca-app-pub-6445940059153239/2776592093', reward: 'ca-app-pub-6445940059153239/3483169109' };
  let P = null;
  try { const c = window.Capacitor; if (c && c.isNativePlatform && c.isNativePlatform()) P = (c.Plugins && c.Plugins.AdMob) || null; } catch (e) {}
  const am = { native: !!P, canAds: false, privacy: false, shim: null };
  if (!P) return am;
  if (TESTING) {   // test builds only: a small box with the frame rate and the drawing settings, to hunt slowdowns
    try {
      const el = document.createElement('div');
      el.style.cssText = 'position:fixed;left:4px;bottom:4px;z-index:99999;font:11px monospace;color:#0f0;background:rgba(0,0,0,.65);padding:2px 5px;pointer-events:none;white-space:pre';
      document.body.appendChild(el);
      let n = 0, t0 = performance.now(), worst = 0, last = t0;
      const tick = t => { n++; worst = Math.max(worst, t - last); last = t; requestAnimationFrame(tick); };
      requestAnimationFrame(tick);
      setInterval(() => {
        const now = performance.now(), fps = n * 1000 / (now - t0);
        let q = ''; try { q = 'q' + quality + ' P' + PCAP + ' dpr' + DPR.toFixed(2) + ' ' + cv.width + 'x' + cv.height; } catch (e) {}
        el.textContent = fps.toFixed(0) + ' fps  worst ' + worst.toFixed(0) + 'ms  ' + q + '\n' + (navigator.hardwareConcurrency || '?') + ' cores  ' + (navigator.deviceMemory || '?') + 'GB  webview ' + ((/Chrome\/([\d.]+)/.exec(navigator.userAgent) || [])[1] || '?');
        n = 0; t0 = now; worst = 0;
      }, 1000);
    } catch (e) {}
  }
  const ev = { INTERSTITIAL_STATE_CHANGED: 'inter', REWARDED_STATE_CHANGED: 'rew' };
  const subs = { inter: new Set(), rew: new Set() };
  const emit = (k, s) => {
    if (s === 'opened') { try { if (AC) AC.suspend(); } catch (e) {} }
    else if (s === 'closed' || s === 'failed') { try { if (AC && !document.hidden) AC.resume(); } catch (e) {} }
    subs[k].forEach(f => { try { f(s); } catch (e) {} });
  };
  const fail = k => setTimeout(() => emit(k, 'failed'), 0);
  const st = { inter: { ready: false, loading: null }, rew: { ready: false, loading: null } };
  const load = k => {
    const s = st[k];
    if (!am.canAds) return Promise.resolve();
    if (s.ready) return Promise.resolve();
    if (s.loading) return s.loading;
    let p;
    try { p = k === 'inter' ? P.prepareInterstitial({ adId: IDS.inter, isTesting: TESTING }) : P.prepareRewardVideoAd({ adId: IDS.reward, isTesting: TESTING }); } catch (e) { p = Promise.reject(e); }
    return s.loading = Promise.resolve(p).then(() => { s.ready = true; }, () => { s.ready = false; }).then(() => { s.loading = null; });
  };
  const show = async k => {
    const s = st[k];
    if (!am.canAds) { fail(k); return; }
    if (k === 'inter' && !s.ready) { load(k); fail(k); return; }   // an interstitial never makes the game wait
    await load(k);
    if (!s.ready) { fail(k); return; }
    s.ready = false;
    try { if (k === 'inter') await P.showInterstitial(); else await P.showRewardVideoAd(); } catch (e) { fail(k); }
  };
  const L = (e, f) => { try { P.addListener(e, f); } catch (x) {} };
  L('interstitialAdShowed', () => emit('inter', 'opened'));
  L('interstitialAdDismissed', () => { emit('inter', 'closed'); load('inter'); });
  L('interstitialAdFailedToShow', () => emit('inter', 'failed'));
  L('onRewardedVideoAdShowed', () => emit('rew', 'opened'));
  L('onRewardedVideoAdReward', () => emit('rew', 'rewarded'));
  L('onRewardedVideoAdDismissed', () => { emit('rew', 'closed'); load('rew'); });
  L('onRewardedVideoAdFailedToShow', () => emit('rew', 'failed'));
  am.shim = { EVENT_NAME: ev, advertisement: {
    on(e, f) { if (subs[e]) subs[e].add(f); }, off(e, f) { if (subs[e]) subs[e].delete(f); },
    showInterstitial() { show('inter'); }, showRewarded() { show('rew'); } } };
  /* at start-up: ask for consent when the region needs it (EEA / UK), then start the SDK and load the first ads */
  am.start = async () => {
    // Asking for consent while the game is starting makes it crawl on some phones (10-15 fps instead of 65):
    // tested, the same call 20 s later is harmless. So wait until the game is up and settled.
    await new Promise(r => setTimeout(r, 20000));
    let dbg = '';
    try {
      let i = await P.requestConsentInfo({ tagForUnderAgeOfConsent: false });
      dbg = 'CONSENT ' + (i && i.status) + (i && i.isConsentFormAvailable ? ' FORM' : ' NOFORM');
      if (i && i.isConsentFormAvailable && i.status === 'REQUIRED') { i = await P.showConsentForm(); dbg += ' > ' + (i && i.status); }
      am.privacy = !!i && i.privacyOptionsRequirementStatus === 'REQUIRED';
      am.canAds = !!(i && i.canRequestAds);
      dbg += am.canAds ? ' ADS OK' : ' NO ADS';
    } catch (e) { dbg = 'CONSENT ERROR ' + ((e && (e.message || e.code)) || e); }
    if (!am.canAds) return;
    try { await P.initialize({}); } catch (e) { am.canAds = false; return; }
    load('inter'); load('rew');
  };
  am.openPrivacy = async () => { try { await P.showPrivacyOptionsForm(); } catch (e) {} };
  return am;
})();

