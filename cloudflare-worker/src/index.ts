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
  <title>FlowShift for Teams — Event Staffing Platform</title>
  <meta property="og:title" content="FlowShift for Teams">
  <meta property="og:description" content="Manage your event staffing operation from one platform. Centralized staff pool, multi-manager coordination, and Stripe billing.">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://flowshift.work/business">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      color: #fff;
      min-height: 100vh;
    }
    .page { max-width: 720px; margin: 0 auto; padding: 40px 20px 60px; }

    /* Hero */
    .hero { text-align: center; padding: 40px 0 48px; }
    .logo {
      font-size: 32px;
      font-weight: 800;
      background: linear-gradient(135deg, #e94560, #ff6b6b);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 24px;
    }
    .hero h1 {
      font-size: 28px;
      font-weight: 800;
      line-height: 1.3;
      margin-bottom: 12px;
    }
    .hero p {
      font-size: 16px;
      color: rgba(255,255,255,0.7);
      max-width: 500px;
      margin: 0 auto;
      line-height: 1.5;
    }

    /* Cards */
    .cards { display: grid; gap: 16px; margin-bottom: 48px; }
    @media (min-width: 520px) { .cards { grid-template-columns: repeat(3, 1fr); } }
    .card {
      background: rgba(255,255,255,0.07);
      border-radius: 16px;
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255,255,255,0.1);
      padding: 24px;
      text-align: center;
    }
    .card-icon {
      font-size: 36px;
      margin-bottom: 12px;
    }
    .card h3 {
      font-size: 16px;
      font-weight: 700;
      margin-bottom: 8px;
    }
    .card p {
      font-size: 13px;
      color: rgba(255,255,255,0.6);
      line-height: 1.5;
    }

    /* Steps */
    .steps {
      background: rgba(255,255,255,0.05);
      border-radius: 16px;
      border: 1px solid rgba(255,255,255,0.08);
      padding: 32px 24px;
      margin-bottom: 48px;
    }
    .steps h2 {
      text-align: center;
      font-size: 20px;
      font-weight: 700;
      margin-bottom: 24px;
    }
    .step {
      display: flex;
      align-items: flex-start;
      gap: 16px;
      margin-bottom: 20px;
    }
    .step:last-child { margin-bottom: 0; }
    .step-num {
      flex-shrink: 0;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: linear-gradient(135deg, #e94560, #ff6b6b);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 14px;
    }
    .step-text h4 { font-size: 15px; font-weight: 600; margin-bottom: 4px; }
    .step-text p { font-size: 13px; color: rgba(255,255,255,0.6); line-height: 1.4; }

    /* CTA */
    .cta { text-align: center; margin-bottom: 48px; }
    .cta h2 { font-size: 20px; font-weight: 700; margin-bottom: 20px; }
    .btn {
      display: inline-block;
      padding: 14px 28px;
      border-radius: 14px;
      font-size: 15px;
      font-weight: 600;
      text-decoration: none;
      text-align: center;
      margin: 6px;
      transition: transform 0.2s, opacity 0.2s;
    }
    .btn:hover { transform: scale(1.02); }
    .btn:active { transform: scale(0.98); }
    .btn-apple { background: #fff; color: #000; }
    .btn-google {
      background: rgba(255,255,255,0.15);
      color: #fff;
      border: 1px solid rgba(255,255,255,0.2);
    }

    /* Footer */
    .footer {
      text-align: center;
      padding-top: 24px;
      border-top: 1px solid rgba(255,255,255,0.08);
      font-size: 13px;
      color: rgba(255,255,255,0.35);
    }
    .footer a {
      color: rgba(255,255,255,0.5);
      text-decoration: none;
    }
    .footer a:hover { color: rgba(255,255,255,0.8); }
  </style>
</head>
<body>
  <div class="page">
    <div class="hero">
      <div class="logo">FlowShift</div>
      <h1>FlowShift for Teams</h1>
      <p>Manage your event staffing operation from one platform. Schedule shifts, coordinate managers, and streamline payroll.</p>
    </div>

    <div class="cards">
      <div class="card">
        <div class="card-icon">&#x1F465;</div>
        <h3>Centralized Staff Pool</h3>
        <p>Maintain one vetted roster across your entire organization. Control who gets assigned to events.</p>
      </div>
      <div class="card">
        <div class="card-icon">&#x1F4CB;</div>
        <h3>Multi-Manager Coordination</h3>
        <p>Invite multiple managers, set roles and permissions. Everyone works from the same playbook.</p>
      </div>
      <div class="card">
        <div class="card-icon">&#x1F4B3;</div>
        <h3>Stripe Billing</h3>
        <p>One subscription covers your whole team. Manage billing through the Stripe customer portal.</p>
      </div>
    </div>

    <div class="steps">
      <h2>How It Works</h2>
      <div class="step">
        <div class="step-num">1</div>
        <div class="step-text">
          <h4>Sign up as a manager</h4>
          <p>Download FlowShift and create your manager account in under a minute.</p>
        </div>
      </div>
      <div class="step">
        <div class="step-num">2</div>
        <div class="step-text">
          <h4>Create your organization</h4>
          <p>Set up your company profile, choose open or restricted staff policies, and configure billing.</p>
        </div>
      </div>
      <div class="step">
        <div class="step-num">3</div>
        <div class="step-text">
          <h4>Invite your team</h4>
          <p>Add managers by email, build your staff roster, and start scheduling events together.</p>
        </div>
      </div>
    </div>

    <div class="cta">
      <h2>Get Started</h2>
      <a href="${appStoreUrl}" class="btn btn-apple">Download on the App Store</a>
      <a href="${playStoreUrl}" class="btn btn-google">Get it on Google Play</a>
    </div>

    <div class="footer">
      <p><a href="https://flowshift.work/support">Support</a> &middot; <a href="mailto:contact@flowshift.work">contact@flowshift.work</a></p>
      <p style="margin-top: 8px;">Powered by FlowShift</p>
    </div>
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
