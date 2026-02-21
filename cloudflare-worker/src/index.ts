/**
 * Cloudflare Worker for flowshift.work
 *
 * Serves:
 * - /.well-known/apple-app-site-association (iOS Universal Links)
 * - /.well-known/assetlinks.json (Android App Links)
 * - /invite/:shortCode and /p/:shortCode (Smart fallback landing pages)
 */

interface Env {
  API_BASE_URL: string;
  APP_STORE_URL: string;
  PLAY_STORE_URL: string;
}

const AASA = {
  applinks: {
    apps: [],
    details: [
      {
        appID: 'XXXXXXXXXX.com.pymesoft.nexa', // TODO: Replace XXXXXXXXXX with your Apple Team ID
        paths: ['/invite/*', '/p/*'],
      },
    ],
  },
};

const ASSET_LINKS = [
  {
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'com.pymesoft.nexa',
      sha256_cert_fingerprints: [
        // TODO: Replace with actual SHA256 fingerprint from signing key
        'PLACEHOLDER:SHA256:FINGERPRINT',
      ],
    },
  },
];

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers for all responses
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Apple App Site Association
    if (path === '/.well-known/apple-app-site-association') {
      return new Response(JSON.stringify(AASA), {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=3600',
          ...corsHeaders,
        },
      });
    }

    // Android Asset Links
    if (path === '/.well-known/assetlinks.json') {
      return new Response(JSON.stringify(ASSET_LINKS), {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=3600',
          ...corsHeaders,
        },
      });
    }

    // Invite deep link handler: /invite/:shortCode or /p/:shortCode
    const inviteMatch = path.match(/^\/(invite|p)\/([A-Za-z0-9]{6})$/);
    if (inviteMatch) {
      const shortCode = inviteMatch[2].toUpperCase();
      const isPublicLink = inviteMatch[1] === 'p';

      // Fetch invite details from the API for the landing page
      let teamName = 'a team';
      let teamDescription = '';
      let memberCount = 0;
      let valid = false;

      try {
        const apiUrl = `${env.API_BASE_URL}/api/invites/validate/${shortCode}`;
        const apiResponse = await fetch(apiUrl, {
          headers: { 'Content-Type': 'application/json' },
        });
        if (apiResponse.ok) {
          const data = (await apiResponse.json()) as Record<string, unknown>;
          if (data.valid) {
            valid = true;
            teamName = (data.teamName as string) || teamName;
            teamDescription = (data.teamDescription as string) || '';
            memberCount = (data.memberCount as number) || 0;
          }
        }
      } catch {
        // If API is unreachable, still show the fallback page
      }

      const html = buildLandingPage({
        shortCode,
        teamName,
        teamDescription,
        memberCount,
        valid,
        isPublicLink,
        appStoreUrl: env.APP_STORE_URL,
        playStoreUrl: env.PLAY_STORE_URL,
      });

      return new Response(html, {
        headers: {
          'Content-Type': 'text/html;charset=UTF-8',
          ...corsHeaders,
        },
      });
    }

    // Business landing page
    if (path === '/business') {
      const html = buildBusinessPage(env);
      return new Response(html, {
        headers: {
          'Content-Type': 'text/html;charset=UTF-8',
          'Cache-Control': 'public, max-age=3600',
          ...corsHeaders,
        },
      });
    }

    // Checkout success page
    if (path === '/checkout/success') {
      const html = buildCheckoutResultPage({
        success: true,
        appStoreUrl: env.APP_STORE_URL,
        playStoreUrl: env.PLAY_STORE_URL,
      });
      return new Response(html, {
        headers: { 'Content-Type': 'text/html;charset=UTF-8', ...corsHeaders },
      });
    }

    // Checkout cancel page
    if (path === '/checkout/cancel') {
      const html = buildCheckoutResultPage({
        success: false,
        appStoreUrl: env.APP_STORE_URL,
        playStoreUrl: env.PLAY_STORE_URL,
      });
      return new Response(html, {
        headers: { 'Content-Type': 'text/html;charset=UTF-8', ...corsHeaders },
      });
    }

    // Root redirect
    if (path === '/' || path === '') {
      return Response.redirect('https://flowshift.app', 302);
    }

    return new Response('Not Found', { status: 404 });
  },
};

function buildLandingPage(opts: {
  shortCode: string;
  teamName: string;
  teamDescription: string;
  memberCount: number;
  valid: boolean;
  isPublicLink: boolean;
  appStoreUrl: string;
  playStoreUrl: string;
}): string {
  const {
    shortCode,
    teamName,
    teamDescription,
    memberCount,
    valid,
    isPublicLink,
    appStoreUrl,
    playStoreUrl,
  } = opts;

  const linkType = isPublicLink ? 'p' : 'invite';
  const title = valid
    ? `Join ${teamName} on FlowShift`
    : 'FlowShift - Team Invitation';
  const subtitle = isPublicLink
    ? `${teamName} is hiring! Apply to join the team.`
    : `You've been invited to join ${teamName} on FlowShift.`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(subtitle)}">
  <meta property="og:type" content="website">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      color: #fff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .container {
      max-width: 420px;
      width: 90%;
      padding: 40px 32px;
      background: rgba(255,255,255,0.07);
      border-radius: 24px;
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255,255,255,0.1);
      text-align: center;
    }
    .logo {
      font-size: 32px;
      font-weight: 800;
      background: linear-gradient(135deg, #e94560, #ff6b6b);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 8px;
    }
    .team-name {
      font-size: 22px;
      font-weight: 700;
      margin: 20px 0 8px;
    }
    .description {
      font-size: 14px;
      color: rgba(255,255,255,0.7);
      margin-bottom: 8px;
    }
    .member-count {
      font-size: 13px;
      color: rgba(255,255,255,0.5);
      margin-bottom: 24px;
    }
    .code-box {
      background: rgba(255,255,255,0.1);
      border: 2px dashed rgba(255,255,255,0.3);
      border-radius: 12px;
      padding: 16px;
      margin: 20px 0;
    }
    .code-label {
      font-size: 12px;
      color: rgba(255,255,255,0.5);
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 8px;
    }
    .code-value {
      font-size: 32px;
      font-weight: 800;
      letter-spacing: 4px;
      font-family: 'SF Mono', 'Fira Code', monospace;
    }
    .btn {
      display: block;
      width: 100%;
      padding: 16px;
      border-radius: 14px;
      font-size: 16px;
      font-weight: 600;
      text-decoration: none;
      text-align: center;
      margin-bottom: 12px;
      transition: transform 0.2s, opacity 0.2s;
    }
    .btn:hover { transform: scale(1.02); }
    .btn:active { transform: scale(0.98); }
    .btn-apple {
      background: #fff;
      color: #000;
    }
    .btn-google {
      background: rgba(255,255,255,0.15);
      color: #fff;
      border: 1px solid rgba(255,255,255,0.2);
    }
    .divider {
      display: flex;
      align-items: center;
      margin: 24px 0 16px;
      color: rgba(255,255,255,0.3);
      font-size: 12px;
    }
    .divider::before, .divider::after {
      content: '';
      flex: 1;
      border-top: 1px solid rgba(255,255,255,0.15);
    }
    .divider span { padding: 0 12px; }
    .invalid-notice {
      background: rgba(233, 69, 96, 0.2);
      border: 1px solid rgba(233, 69, 96, 0.4);
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 20px;
      font-size: 14px;
    }
    .footer {
      margin-top: 24px;
      font-size: 12px;
      color: rgba(255,255,255,0.3);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">FlowShift</div>

    ${
      !valid
        ? `<div class="invalid-notice">This invite link may have expired or been revoked. You can still try the code below in the app.</div>`
        : ''
    }

    <div class="team-name">${escapeHtml(teamName)}</div>
    ${teamDescription ? `<div class="description">${escapeHtml(teamDescription)}</div>` : ''}
    ${memberCount > 0 ? `<div class="member-count">${memberCount} team member${memberCount !== 1 ? 's' : ''}</div>` : ''}

    <p class="description">${escapeHtml(subtitle)}</p>

    <a href="${appStoreUrl}" class="btn btn-apple">
      Download on the App Store
    </a>
    <a href="${playStoreUrl}" class="btn btn-google">
      Get it on Google Play
    </a>

    <div class="divider"><span>or enter this code in the app</span></div>

    <div class="code-box">
      <div class="code-label">Invite Code</div>
      <div class="code-value">${escapeHtml(shortCode)}</div>
    </div>

    <div class="footer">Powered by FlowShift</div>
  </div>

  <script>
    // Store shortCode in localStorage for deferred deep linking
    try {
      localStorage.setItem('flowshift_invite_code', '${shortCode}');
      localStorage.setItem('flowshift_invite_type', '${linkType}');
      localStorage.setItem('flowshift_invite_ts', Date.now().toString());
    } catch(e) {}

    // Auto-redirect to appropriate store after 2 seconds
    // (only if the app didn't intercept via Universal/App Links)
    setTimeout(function() {
      var ua = navigator.userAgent || '';
      if (/iPhone|iPad|iPod/i.test(ua)) {
        window.location.href = '${appStoreUrl}';
      } else if (/Android/i.test(ua)) {
        window.location.href = '${playStoreUrl}';
      }
    }, 2000);
  </script>
</body>
</html>`;
}

function buildBusinessPage(env: Env): string {
  const appStoreUrl = env.APP_STORE_URL;
  const playStoreUrl = env.PLAY_STORE_URL;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>FlowShift for Business — Enterprise Event Staffing</title>
  <meta property="og:title" content="FlowShift for Business">
  <meta property="og:description" content="Enterprise event staffing management. Per-seat billing, multi-manager coordination, centralized staff pools.">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://flowshift.work/business">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    html { scroll-behavior: smooth; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      color: #fff;
      min-height: 100vh;
      background: #1a1a2e;
    }

    /* ── Dark sections ── */
    .section-dark {
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      padding: 80px 20px;
    }

    /* ── Light sections ── */
    .section-light {
      background: #f8f9fc;
      color: #1a1a2e;
      padding: 80px 20px;
    }

    .inner { max-width: 960px; margin: 0 auto; }

    /* ── Hero ── */
    .hero { text-align: center; padding: 100px 20px 80px; }
    .hero .logo {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 16px;
      margin-bottom: 16px;
    }
    .hero .logo img {
      width: 72px;
      height: 72px;
      border-radius: 16px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    }
    .hero .logo span {
      font-size: 42px;
      font-weight: 800;
      color: #fff;
    }
    .hero h1 {
      font-size: 36px;
      font-weight: 800;
      line-height: 1.2;
      margin-bottom: 16px;
    }
    .hero p {
      font-size: 18px;
      color: rgba(255,255,255,0.7);
      max-width: 560px;
      margin: 0 auto 32px;
      line-height: 1.6;
    }
    .btn-hero {
      display: inline-block;
      padding: 16px 40px;
      border-radius: 14px;
      font-size: 17px;
      font-weight: 700;
      text-decoration: none;
      background: linear-gradient(135deg, #e94560, #ff6b6b);
      color: #fff;
      transition: transform 0.2s, box-shadow 0.2s;
      box-shadow: 0 4px 24px rgba(233, 69, 96, 0.4);
    }
    .btn-hero:hover { transform: scale(1.04); box-shadow: 0 6px 32px rgba(233, 69, 96, 0.5); }
    .btn-hero:active { transform: scale(0.98); }

    /* ── Section titles ── */
    .section-title {
      text-align: center;
      font-size: 28px;
      font-weight: 800;
      margin-bottom: 48px;
    }
    .section-light .section-title { color: #1a1a2e; }

    /* ── Feature cards ── */
    .features-grid {
      display: grid;
      gap: 20px;
      grid-template-columns: 1fr;
    }
    @media (min-width: 520px) { .features-grid { grid-template-columns: repeat(2, 1fr); } }
    @media (min-width: 768px) { .features-grid { grid-template-columns: repeat(3, 1fr); } }

    .feature-card {
      background: rgba(255,255,255,0.07);
      border-radius: 20px;
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255,255,255,0.1);
      padding: 28px 24px;
      text-align: center;
      transition: transform 0.25s ease;
    }
    .feature-card:hover { transform: translateY(-4px); }
    .feature-icon { font-size: 40px; margin-bottom: 16px; }
    .feature-card h3 { font-size: 17px; font-weight: 700; margin-bottom: 8px; }
    .feature-card p { font-size: 14px; color: rgba(255,255,255,0.6); line-height: 1.5; }

    /* ── How it works ── */
    .steps-list { max-width: 640px; margin: 0 auto; }
    .step {
      display: flex;
      align-items: flex-start;
      gap: 20px;
      margin-bottom: 32px;
    }
    .step:last-child { margin-bottom: 0; }
    .step-num {
      flex-shrink: 0;
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: linear-gradient(135deg, #e94560, #ff6b6b);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 18px;
      color: #fff;
    }
    .step-content h4 {
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 4px;
      color: #1a1a2e;
    }
    .step-content p {
      font-size: 15px;
      color: #555;
      line-height: 1.5;
    }

    /* ── Pricing ── */
    .pricing-card {
      max-width: 480px;
      margin: 0 auto;
      background: rgba(255,255,255,0.07);
      border-radius: 24px;
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255,255,255,0.12);
      padding: 40px 32px;
      text-align: center;
    }
    .pricing-card h3 {
      font-size: 22px;
      font-weight: 800;
      margin-bottom: 28px;
    }
    .price-row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      padding: 14px 0;
      border-bottom: 1px solid rgba(255,255,255,0.08);
    }
    .price-row:last-of-type { border-bottom: none; }
    .price-label {
      font-size: 16px;
      font-weight: 600;
    }
    .price-value {
      font-size: 20px;
      font-weight: 800;
      background: linear-gradient(135deg, #FFC107, #FFD54F);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .pricing-note {
      margin-top: 20px;
      font-size: 14px;
      color: rgba(255,255,255,0.5);
      line-height: 1.5;
    }
    .pricing-example {
      margin-top: 20px;
      padding: 16px;
      background: rgba(255,255,255,0.05);
      border-radius: 12px;
      font-size: 15px;
      color: rgba(255,255,255,0.7);
    }
    .pricing-example strong {
      color: #FFC107;
    }

    /* ── CTA ── */
    .cta-section { text-align: center; }
    .cta-section h2 {
      font-size: 28px;
      font-weight: 800;
      margin-bottom: 24px;
    }
    .cta-buttons { margin-bottom: 20px; }
    .btn-store {
      display: inline-block;
      padding: 14px 28px;
      border-radius: 14px;
      font-size: 15px;
      font-weight: 600;
      text-decoration: none;
      text-align: center;
      margin: 6px;
      transition: transform 0.2s;
    }
    .btn-store:hover { transform: scale(1.03); }
    .btn-store:active { transform: scale(0.97); }
    .btn-apple { background: #fff; color: #000; }
    .btn-google {
      background: rgba(255,255,255,0.15);
      color: #fff;
      border: 1px solid rgba(255,255,255,0.2);
    }
    .cta-note {
      font-size: 15px;
      color: rgba(255,255,255,0.55);
      line-height: 1.6;
    }
    .cta-note a {
      color: #FFC107;
      text-decoration: none;
    }
    .cta-note a:hover { text-decoration: underline; }

    /* ── Footer ── */
    .footer {
      text-align: center;
      padding: 32px 20px;
      background: #0d0d1a;
      font-size: 13px;
      color: rgba(255,255,255,0.35);
    }
    .footer a {
      color: rgba(255,255,255,0.5);
      text-decoration: none;
    }
    .footer a:hover { color: rgba(255,255,255,0.8); }

    @media (max-width: 520px) {
      .hero h1 { font-size: 28px; }
      .hero p { font-size: 16px; }
      .section-title { font-size: 24px; }
      .section-dark, .section-light { padding: 60px 16px; }
    }
  </style>
</head>
<body>

  <!-- Hero -->
  <div class="section-dark hero">
    <div class="inner">
      <div class="logo">
        <img src="data:image/png;base64,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" alt="FlowShift" />
        <span>FlowShift</span>
      </div>
      <h1>FlowShift for Business</h1>
      <p>Enterprise event staffing management. Per-seat billing, multi-manager coordination, centralized staff pools.</p>
      <a href="#pricing" class="btn-hero">Get Started</a>
    </div>
  </div>

  <!-- Features -->
  <div class="section-dark">
    <div class="inner">
      <div class="section-title">Built for Staffing Operations</div>
      <div class="features-grid">
        <div class="feature-card">
          <div class="feature-icon">&#x1F465;</div>
          <h3>Centralized Staff Pool</h3>
          <p>One vetted roster shared across your entire organization. No duplicate profiles, no confusion.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">&#x1F4CB;</div>
          <h3>Multi-Manager Coordination</h3>
          <p>Invite managers, set roles and permissions. Everyone works from the same real-time playbook.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">&#x1F4B0;</div>
          <h3>Per-Seat Billing</h3>
          <p>Pay only for active staff accounts. Your bill scales up or down automatically with your team size.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">&#x26A1;</div>
          <h3>Real-Time Sync</h3>
          <p>All managers see the same schedules, shift changes, and staff availability — updated instantly.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">&#x1F512;</div>
          <h3>Staff Policy Control</h3>
          <p>Choose open hiring or restricted rosters. Control who joins and who gets assigned to events.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">&#x1F4B3;</div>
          <h3>Stripe Billing Portal</h3>
          <p>Manage invoices, update payment methods, and view billing history through Stripe&rsquo;s secure portal.</p>
        </div>
      </div>
    </div>
  </div>

  <!-- How It Works -->
  <div class="section-light">
    <div class="inner">
      <div class="section-title">How It Works</div>
      <div class="steps-list">
        <div class="step">
          <div class="step-num">1</div>
          <div class="step-content">
            <h4>Sign up as a manager</h4>
            <p>Download FlowShift and create your manager account in under a minute.</p>
          </div>
        </div>
        <div class="step">
          <div class="step-num">2</div>
          <div class="step-content">
            <h4>Create your organization</h4>
            <p>Set up your company profile, choose staff policies, and configure per-seat billing.</p>
          </div>
        </div>
        <div class="step">
          <div class="step-num">3</div>
          <div class="step-content">
            <h4>Add managers and build your roster</h4>
            <p>Invite managers by email and start building your centralized staff pool.</p>
          </div>
        </div>
        <div class="step">
          <div class="step-num">4</div>
          <div class="step-content">
            <h4>Billing auto-adjusts</h4>
            <p>As your team grows or shrinks, your subscription updates automatically. No manual changes needed.</p>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Pricing -->
  <div class="section-dark" id="pricing">
    <div class="inner">
      <div class="section-title">Simple, Transparent Pricing</div>
      <div class="pricing-card">
        <h3>Per-Seat Pricing</h3>
        <div class="price-row">
          <span class="price-label">Manager Seat</span>
          <span class="price-value">$9.99/mo</span>
        </div>
        <div class="price-row">
          <span class="price-label">Staff Seat</span>
          <span class="price-value">$6.00/mo</span>
        </div>
        <div class="pricing-note">Scales with your team. Cancel anytime.</div>
        <div class="pricing-example">
          <strong>Example:</strong> 4 managers + 30 staff = <strong>$219.96/mo</strong>
        </div>
      </div>
    </div>
  </div>

  <!-- CTA -->
  <div class="section-dark cta-section" style="padding-top:40px;">
    <div class="inner">
      <h2>Ready to scale your staffing operation?</h2>
      <div class="cta-buttons">
        <a href="${appStoreUrl}" class="btn-store btn-apple">Download on the App Store</a>
        <a href="${playStoreUrl}" class="btn-store btn-google">Get it on Google Play</a>
      </div>
      <p class="cta-note">
        Then create your organization from the app<br>
        or contact us at <a href="mailto:contact@flowshift.work">contact@flowshift.work</a>
      </p>
    </div>
  </div>

  <!-- Footer -->
  <div class="footer">
    <p><a href="https://flowshift.work/support">Support</a> &middot; <a href="mailto:contact@flowshift.work">contact@flowshift.work</a></p>
    <p style="margin-top: 8px;">Powered by FlowShift</p>
  </div>

</body>
</html>`;
}

function buildCheckoutResultPage(opts: {
  success: boolean;
  appStoreUrl: string;
  playStoreUrl: string;
}): string {
  const { success, appStoreUrl, playStoreUrl } = opts;
  const title = success ? 'Subscription Activated!' : 'Checkout Canceled';
  const icon = success ? '&#x2705;' : '&#x274C;';
  const message = success
    ? 'Your FlowShift Pro for Teams subscription is now active. Head back to the app to start using your organization features.'
    : 'Your checkout was canceled. No charges were made. You can try again anytime from the app.';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} — FlowShift</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      color: #fff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .container {
      max-width: 420px;
      width: 90%;
      padding: 40px 32px;
      background: rgba(255,255,255,0.07);
      border-radius: 24px;
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255,255,255,0.1);
      text-align: center;
    }
    .logo {
      font-size: 32px;
      font-weight: 800;
      background: linear-gradient(135deg, #e94560, #ff6b6b);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 24px;
    }
    .icon { font-size: 48px; margin-bottom: 16px; }
    h1 { font-size: 22px; font-weight: 700; margin-bottom: 12px; }
    p { font-size: 15px; color: rgba(255,255,255,0.7); line-height: 1.5; margin-bottom: 24px; }
    .btn {
      display: inline-block;
      padding: 14px 28px;
      border-radius: 14px;
      font-size: 15px;
      font-weight: 600;
      text-decoration: none;
      margin: 6px;
      transition: transform 0.2s;
    }
    .btn:hover { transform: scale(1.02); }
    .btn-apple { background: #fff; color: #000; }
    .btn-google {
      background: rgba(255,255,255,0.15);
      color: #fff;
      border: 1px solid rgba(255,255,255,0.2);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">FlowShift</div>
    <div class="icon">${icon}</div>
    <h1>${title}</h1>
    <p>${message}</p>
    <a href="${appStoreUrl}" class="btn btn-apple">Open on iOS</a>
    <a href="${playStoreUrl}" class="btn btn-google">Open on Android</a>
  </div>
</body>
</html>`;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
