import { Router } from 'express';

const router = Router();

// Account Deletion Page for TIE Staff App (Play Store requirement)
router.get('/privacy/tie-staff/delete-account', (_req, res) => {
  res.setHeader('Content-Type', 'text/html');
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Delete Your Account - TIE Staff</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      line-height: 1.6;
      color: #333;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 20px;
    }
    .container {
      max-width: 700px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      overflow: hidden;
    }
    .header {
      background: #1a1a2e;
      color: white;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      font-size: 28px;
      margin-bottom: 10px;
    }
    .header p {
      opacity: 0.8;
      font-size: 16px;
    }
    .content {
      padding: 40px 30px;
    }
    h2 {
      color: #1a1a2e;
      margin-bottom: 20px;
      font-size: 22px;
    }
    .steps {
      background: #f8f9fa;
      border-radius: 12px;
      padding: 25px;
      margin-bottom: 30px;
    }
    .step {
      display: flex;
      margin-bottom: 20px;
      align-items: flex-start;
    }
    .step:last-child { margin-bottom: 0; }
    .step-number {
      background: #667eea;
      color: white;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: bold;
      margin-right: 15px;
      flex-shrink: 0;
    }
    .step-content h3 {
      font-size: 16px;
      margin-bottom: 5px;
      color: #1a1a2e;
    }
    .step-content p {
      color: #666;
      font-size: 14px;
    }
    .data-section {
      margin-bottom: 30px;
    }
    .data-section h3 {
      color: #1a1a2e;
      margin-bottom: 15px;
      font-size: 18px;
    }
    .data-list {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 10px;
    }
    .data-item {
      background: #fff3f3;
      border-left: 4px solid #e74c3c;
      padding: 12px 15px;
      border-radius: 0 8px 8px 0;
      font-size: 14px;
    }
    .data-item.retained {
      background: #f0f9ff;
      border-left-color: #3498db;
    }
    .timeline {
      background: #e8f5e9;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 30px;
    }
    .timeline h3 {
      color: #2e7d32;
      margin-bottom: 10px;
    }
    .timeline p {
      color: #555;
    }
    .contact {
      background: #1a1a2e;
      color: white;
      padding: 25px;
      border-radius: 12px;
      text-align: center;
    }
    .contact h3 {
      margin-bottom: 15px;
    }
    .contact a {
      color: #667eea;
      text-decoration: none;
      font-weight: 600;
    }
    .contact a:hover {
      text-decoration: underline;
    }
    .alternative {
      margin-top: 30px;
      padding: 20px;
      background: #fff8e1;
      border-radius: 12px;
      border-left: 4px solid #ff9800;
    }
    .alternative h3 {
      color: #e65100;
      margin-bottom: 10px;
    }
    @media (max-width: 480px) {
      .header { padding: 30px 20px; }
      .header h1 { font-size: 24px; }
      .content { padding: 30px 20px; }
      .data-list { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Delete Your Account</h1>
      <p>TIE Staff App - Account & Data Deletion</p>
    </div>

    <div class="content">
      <h2>How to Delete Your Account</h2>

      <div class="steps">
        <div class="step">
          <div class="step-number">1</div>
          <div class="step-content">
            <h3>Open the TIE Staff App</h3>
            <p>Launch the app on your mobile device and ensure you're logged in.</p>
          </div>
        </div>

        <div class="step">
          <div class="step-number">2</div>
          <div class="step-content">
            <h3>Go to Settings</h3>
            <p>Tap on your profile icon or navigate to the Settings menu.</p>
          </div>
        </div>

        <div class="step">
          <div class="step-number">3</div>
          <div class="step-content">
            <h3>Select "Delete Account"</h3>
            <p>Scroll down and tap on "Delete Account" option.</p>
          </div>
        </div>

        <div class="step">
          <div class="step-number">4</div>
          <div class="step-content">
            <h3>Confirm Deletion</h3>
            <p>Review the information and confirm your request to permanently delete your account.</p>
          </div>
        </div>
      </div>

      <div class="data-section">
        <h3>Data That Will Be Deleted</h3>
        <div class="data-list">
          <div class="data-item">Profile information</div>
          <div class="data-item">Email address</div>
          <div class="data-item">Phone number</div>
          <div class="data-item">Chat messages</div>
          <div class="data-item">Event history</div>
          <div class="data-item">Preferences</div>
        </div>
      </div>

      <div class="data-section">
        <h3>Data That May Be Retained</h3>
        <div class="data-list">
          <div class="data-item retained">Anonymized analytics</div>
          <div class="data-item retained">Legal/compliance records</div>
        </div>
        <p style="margin-top: 15px; font-size: 14px; color: #666;">
          Some data may be retained for legal compliance, fraud prevention, or legitimate business purposes, but will be anonymized.
        </p>
      </div>

      <div class="timeline">
        <h3>Deletion Timeline</h3>
        <p>Your account and associated data will be permanently deleted within <strong>30 days</strong> of your request. During this period, you may contact us to cancel the deletion.</p>
      </div>

      <div class="alternative">
        <h3>Can't Access the App?</h3>
        <p>If you're unable to access the app, you can request account deletion by emailing us with your registered email address. We'll verify your identity and process your request.</p>
      </div>

      <div class="contact">
        <h3>Contact Us</h3>
        <p>For questions about data deletion or privacy:</p>
        <p style="margin-top: 10px;">
          <a href="mailto:support@pymesoft.site">support@pymesoft.site</a>
        </p>
      </div>
    </div>
  </div>
</body>
</html>
  `);
});

// Privacy Policy Page
router.get('/privacy/tie-staff', (_req, res) => {
  res.setHeader('Content-Type', 'text/html');
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - TIE Staff</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      line-height: 1.8;
      color: #333;
      background: #f5f5f5;
      padding: 20px;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
      background: white;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
      padding: 40px;
    }
    h1 {
      color: #1a1a2e;
      margin-bottom: 10px;
      font-size: 32px;
    }
    .updated {
      color: #666;
      margin-bottom: 30px;
      font-size: 14px;
    }
    h2 {
      color: #1a1a2e;
      margin-top: 30px;
      margin-bottom: 15px;
      font-size: 22px;
      border-bottom: 2px solid #667eea;
      padding-bottom: 10px;
    }
    p { margin-bottom: 15px; }
    ul {
      margin-left: 25px;
      margin-bottom: 15px;
    }
    li { margin-bottom: 8px; }
    .contact-box {
      background: #f8f9fa;
      padding: 20px;
      border-radius: 8px;
      margin-top: 30px;
    }
    a { color: #667eea; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Privacy Policy</h1>
    <p class="updated">Last updated: December 2024</p>

    <p>This Privacy Policy describes how TIE Staff ("we", "us", or "our") collects, uses, and shares information about you when you use our mobile application.</p>

    <h2>Information We Collect</h2>
    <p>We collect information you provide directly to us, including:</p>
    <ul>
      <li>Account information (name, email, phone number)</li>
      <li>Profile information</li>
      <li>Communications and chat messages</li>
      <li>Event participation data</li>
    </ul>

    <h2>How We Use Your Information</h2>
    <p>We use the information we collect to:</p>
    <ul>
      <li>Provide, maintain, and improve our services</li>
      <li>Process event assignments and communications</li>
      <li>Send you notifications about events and updates</li>
      <li>Respond to your comments and questions</li>
    </ul>

    <h2>Information Sharing</h2>
    <p>We do not sell your personal information. We may share your information with:</p>
    <ul>
      <li>Event managers who need to coordinate with you</li>
      <li>Service providers who assist in our operations</li>
      <li>When required by law or to protect our rights</li>
    </ul>

    <h2>Data Security</h2>
    <p>We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.</p>

    <h2>Your Rights</h2>
    <p>You have the right to:</p>
    <ul>
      <li>Access your personal data</li>
      <li>Correct inaccurate data</li>
      <li>Request deletion of your data</li>
      <li>Opt-out of marketing communications</li>
    </ul>

    <h2>Account Deletion</h2>
    <p>You can delete your account at any time through the app settings or by visiting <a href="/privacy/tie-staff/delete-account">our account deletion page</a>.</p>

    <h2>Changes to This Policy</h2>
    <p>We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page.</p>

    <div class="contact-box">
      <h2 style="margin-top: 0; border: none;">Contact Us</h2>
      <p>If you have questions about this Privacy Policy, please contact us at:</p>
      <p><a href="mailto:support@pymesoft.site">support@pymesoft.site</a></p>
    </div>
  </div>
</body>
</html>
  `);
});

// ============================================
// FlowShift Manager Privacy Policy
// ============================================
router.get('/privacy/flowshift-manager', (_req, res) => {
  res.setHeader('Content-Type', 'text/html');
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - FlowShift Manager</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      line-height: 1.8;
      color: #333;
      background: linear-gradient(135deg, #1a1a2e 0%, #2C3E50 100%);
      min-height: 100vh;
      padding: 20px;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      padding: 50px;
    }
    .logo {
      text-align: center;
      margin-bottom: 30px;
    }
    .logo-icon {
      width: 80px;
      height: 80px;
      background: #1a1a2e;
      border-radius: 20px;
      margin: 0 auto 15px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .logo-icon svg {
      width: 50px;
      height: 50px;
    }
    h1 {
      color: #1a1a2e;
      margin-bottom: 10px;
      font-size: 32px;
      text-align: center;
    }
    .updated {
      color: #666;
      margin-bottom: 30px;
      font-size: 14px;
      text-align: center;
    }
    h2 {
      color: #1a1a2e;
      margin-top: 35px;
      margin-bottom: 15px;
      font-size: 20px;
      border-left: 4px solid #D4AF37;
      padding-left: 15px;
    }
    p { margin-bottom: 15px; }
    ul {
      margin-left: 25px;
      margin-bottom: 15px;
    }
    li { margin-bottom: 8px; }
    .highlight-box {
      background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
      padding: 20px;
      border-radius: 12px;
      margin: 20px 0;
      border-left: 4px solid #D4AF37;
    }
    .contact-box {
      background: #1a1a2e;
      color: white;
      padding: 25px;
      border-radius: 12px;
      margin-top: 40px;
      text-align: center;
    }
    .contact-box h2 {
      color: white;
      border: none;
      padding: 0;
      margin-top: 0;
    }
    a { color: #D4AF37; }
    .footer {
      text-align: center;
      margin-top: 30px;
      color: #888;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">
      <div class="logo-icon">
        <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="50" cy="50" r="25" stroke="#D4AF37" stroke-width="8"/>
          <circle cx="50" cy="50" r="10" fill="white"/>
          <path d="M10 50 Q10 10 50 10" stroke="white" stroke-width="8" fill="none" stroke-linecap="round"/>
        </svg>
      </div>
    </div>

    <h1>Privacy Policy</h1>
    <p class="updated">Last updated: January 2026</p>

    <p>This Privacy Policy describes how FlowShift Manager ("we", "us", or "our") collects, uses, and shares information about you when you use our mobile application and services.</p>

    <h2>Information We Collect</h2>
    <p>We collect information you provide directly to us, including:</p>
    <ul>
      <li><strong>Account information:</strong> Name, email address, phone number</li>
      <li><strong>Profile information:</strong> Profile photo, job title, skills</li>
      <li><strong>Event data:</strong> Events you create, staff assignments, schedules</li>
      <li><strong>Communications:</strong> Chat messages within the app</li>
      <li><strong>Location data:</strong> Approximate location for venue services (when permitted)</li>
    </ul>

    <div class="highlight-box">
      <strong>We do not sell your personal data.</strong> Your information is used solely to provide and improve our services.
    </div>

    <h2>How We Use Your Information</h2>
    <p>We use the information we collect to:</p>
    <ul>
      <li>Provide, maintain, and improve our event management services</li>
      <li>Facilitate communication between managers and staff</li>
      <li>Send notifications about events, schedules, and updates</li>
      <li>Process staff assignments and scheduling</li>
      <li>Provide customer support</li>
      <li>Analyze usage to improve the app experience</li>
    </ul>

    <h2>Information Sharing</h2>
    <p>We may share your information with:</p>
    <ul>
      <li><strong>Team members:</strong> Other users in your organization who need to coordinate events</li>
      <li><strong>Service providers:</strong> Third parties who assist in our operations (hosting, analytics)</li>
      <li><strong>Legal requirements:</strong> When required by law or to protect our rights</li>
    </ul>

    <h2>Data Security</h2>
    <p>We implement industry-standard security measures including encryption, secure servers, and access controls to protect your personal information against unauthorized access, alteration, disclosure, or destruction.</p>

    <h2>Data Retention</h2>
    <p>We retain your personal information for as long as your account is active or as needed to provide services. You can request deletion of your data at any time.</p>

    <h2>Your Rights</h2>
    <p>You have the right to:</p>
    <ul>
      <li>Access your personal data</li>
      <li>Correct inaccurate information</li>
      <li>Request deletion of your account and data</li>
      <li>Export your data</li>
      <li>Opt-out of marketing communications</li>
    </ul>

    <h2>Account Deletion</h2>
    <p>You can delete your account at any time through the app settings (Settings → Delete Account). Upon deletion, your personal data will be permanently removed within 30 days. Visit our <a href="/privacy/flowshift-manager/delete-account">account deletion page</a> for more information.</p>

    <h2>Third-Party Services</h2>
    <p>Our app uses the following third-party services:</p>
    <ul>
      <li><strong>Firebase:</strong> Authentication and phone verification</li>
      <li><strong>Google Maps:</strong> Location and venue services</li>
      <li><strong>OneSignal:</strong> Push notifications</li>
      <li><strong>Apple Sign-In / Google Sign-In:</strong> Authentication</li>
    </ul>

    <h2>Children's Privacy</h2>
    <p>Our services are not intended for users under 16 years of age. We do not knowingly collect information from children.</p>

    <h2>Changes to This Policy</h2>
    <p>We may update this Privacy Policy periodically. We will notify you of significant changes through the app or via email.</p>

    <div class="contact-box">
      <h2>Contact Us</h2>
      <p>If you have questions about this Privacy Policy or your data, please contact us:</p>
      <p style="margin-top: 15px; font-size: 18px;">
        <a href="mailto:support@pymesoft.site">support@pymesoft.site</a>
      </p>
    </div>

    <p class="footer">© 2026 PYMESOFT LLC. All rights reserved.</p>
  </div>
</body>
</html>
  `);
});

// FlowShift Manager Account Deletion Page
router.get('/privacy/flowshift-manager/delete-account', (_req, res) => {
  res.setHeader('Content-Type', 'text/html');
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Delete Your Account - FlowShift Manager</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      line-height: 1.6;
      color: #333;
      background: linear-gradient(135deg, #1a1a2e 0%, #2C3E50 100%);
      min-height: 100vh;
      padding: 20px;
    }
    .container {
      max-width: 700px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      overflow: hidden;
    }
    .header {
      background: #1a1a2e;
      color: white;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      font-size: 28px;
      margin-bottom: 10px;
    }
    .header p {
      opacity: 0.8;
      font-size: 16px;
    }
    .content {
      padding: 40px 30px;
    }
    h2 {
      color: #1a1a2e;
      margin-bottom: 20px;
      font-size: 22px;
    }
    .steps {
      background: #f8f9fa;
      border-radius: 12px;
      padding: 25px;
      margin-bottom: 30px;
    }
    .step {
      display: flex;
      margin-bottom: 20px;
      align-items: flex-start;
    }
    .step:last-child { margin-bottom: 0; }
    .step-number {
      background: #D4AF37;
      color: #1a1a2e;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: bold;
      margin-right: 15px;
      flex-shrink: 0;
    }
    .step-content h3 {
      font-size: 16px;
      margin-bottom: 5px;
      color: #1a1a2e;
    }
    .step-content p {
      color: #666;
      font-size: 14px;
    }
    .data-section {
      margin-bottom: 30px;
    }
    .data-section h3 {
      color: #1a1a2e;
      margin-bottom: 15px;
      font-size: 18px;
    }
    .data-list {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 10px;
    }
    .data-item {
      background: #fff3f3;
      border-left: 4px solid #e74c3c;
      padding: 12px 15px;
      border-radius: 0 8px 8px 0;
      font-size: 14px;
    }
    .data-item.retained {
      background: #f0f9ff;
      border-left-color: #3498db;
    }
    .timeline {
      background: #e8f5e9;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 30px;
    }
    .timeline h3 {
      color: #2e7d32;
      margin-bottom: 10px;
    }
    .timeline p {
      color: #555;
    }
    .contact {
      background: #1a1a2e;
      color: white;
      padding: 25px;
      border-radius: 12px;
      text-align: center;
    }
    .contact h3 {
      margin-bottom: 15px;
    }
    .contact a {
      color: #D4AF37;
      text-decoration: none;
      font-weight: 600;
    }
    .contact a:hover {
      text-decoration: underline;
    }
    .alternative {
      margin-top: 30px;
      padding: 20px;
      background: #fff8e1;
      border-radius: 12px;
      border-left: 4px solid #D4AF37;
    }
    .alternative h3 {
      color: #e65100;
      margin-bottom: 10px;
    }
    @media (max-width: 480px) {
      .header { padding: 30px 20px; }
      .header h1 { font-size: 24px; }
      .content { padding: 30px 20px; }
      .data-list { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Delete Your Account</h1>
      <p>FlowShift Manager - Account & Data Deletion</p>
    </div>

    <div class="content">
      <h2>How to Delete Your Account</h2>

      <div class="steps">
        <div class="step">
          <div class="step-number">1</div>
          <div class="step-content">
            <h3>Open FlowShift Manager</h3>
            <p>Launch the app on your mobile device and ensure you're logged in.</p>
          </div>
        </div>

        <div class="step">
          <div class="step-number">2</div>
          <div class="step-content">
            <h3>Go to Settings</h3>
            <p>Tap on the menu icon and navigate to Settings.</p>
          </div>
        </div>

        <div class="step">
          <div class="step-number">3</div>
          <div class="step-content">
            <h3>Select "Delete Account"</h3>
            <p>Scroll down and tap on the "Delete Account" option.</p>
          </div>
        </div>

        <div class="step">
          <div class="step-number">4</div>
          <div class="step-content">
            <h3>Confirm Deletion</h3>
            <p>Review the information and confirm your request to permanently delete your account.</p>
          </div>
        </div>
      </div>

      <div class="data-section">
        <h3>Data That Will Be Deleted</h3>
        <div class="data-list">
          <div class="data-item">Profile information</div>
          <div class="data-item">Email address</div>
          <div class="data-item">Phone number</div>
          <div class="data-item">Chat messages</div>
          <div class="data-item">Event history</div>
          <div class="data-item">Team memberships</div>
          <div class="data-item">Preferences & settings</div>
        </div>
      </div>

      <div class="data-section">
        <h3>Data That May Be Retained</h3>
        <div class="data-list">
          <div class="data-item retained">Anonymized analytics</div>
          <div class="data-item retained">Legal/compliance records</div>
        </div>
        <p style="margin-top: 15px; font-size: 14px; color: #666;">
          Some data may be retained in anonymized form for legal compliance or legitimate business purposes.
        </p>
      </div>

      <div class="timeline">
        <h3>Deletion Timeline</h3>
        <p>Your account and associated data will be permanently deleted within <strong>30 days</strong> of your request. During this period, you may contact us to cancel the deletion.</p>
      </div>

      <div class="alternative">
        <h3>Can't Access the App?</h3>
        <p>If you're unable to access the app, you can request account deletion by emailing us from your registered email address. We'll verify your identity and process your request.</p>
      </div>

      <div class="contact">
        <h3>Contact Us</h3>
        <p>For questions about data deletion or privacy:</p>
        <p style="margin-top: 10px;">
          <a href="mailto:support@pymesoft.site">support@pymesoft.site</a>
        </p>
      </div>
    </div>
  </div>
</body>
</html>
  `);
});

// Support Page for FlowShift Manager
router.get('/support/flowshift-manager', (_req, res) => {
  res.setHeader('Content-Type', 'text/html');
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Support - FlowShift Manager</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      line-height: 1.8;
      color: #333;
      background: linear-gradient(135deg, #1a1a2e 0%, #2C3E50 100%);
      min-height: 100vh;
      padding: 20px;
    }
    .container {
      max-width: 700px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      padding: 50px;
      text-align: center;
    }
    .logo-icon {
      width: 100px;
      height: 100px;
      background: #1a1a2e;
      border-radius: 24px;
      margin: 0 auto 25px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .logo-icon svg {
      width: 60px;
      height: 60px;
    }
    h1 {
      color: #1a1a2e;
      margin-bottom: 10px;
      font-size: 32px;
    }
    .subtitle {
      color: #666;
      margin-bottom: 40px;
      font-size: 18px;
    }
    .contact-card {
      background: #f8f9fa;
      border-radius: 12px;
      padding: 30px;
      margin-bottom: 25px;
    }
    .contact-card h2 {
      color: #1a1a2e;
      margin-bottom: 15px;
      font-size: 20px;
    }
    .contact-card a {
      color: #D4AF37;
      font-size: 20px;
      text-decoration: none;
      font-weight: 600;
    }
    .contact-card a:hover {
      text-decoration: underline;
    }
    .contact-card p {
      color: #666;
      margin-top: 10px;
      font-size: 14px;
    }
    .faq {
      text-align: left;
      margin-top: 40px;
    }
    .faq h2 {
      color: #1a1a2e;
      margin-bottom: 20px;
      text-align: center;
    }
    .faq-item {
      background: #f8f9fa;
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 15px;
    }
    .faq-item h3 {
      color: #1a1a2e;
      margin-bottom: 10px;
      font-size: 16px;
    }
    .faq-item p {
      color: #666;
      font-size: 14px;
    }
    .footer {
      margin-top: 40px;
      color: #888;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo-icon">
      <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="50" cy="50" r="25" stroke="#D4AF37" stroke-width="8"/>
        <circle cx="50" cy="50" r="10" fill="white"/>
        <path d="M10 50 Q10 10 50 10" stroke="white" stroke-width="8" fill="none" stroke-linecap="round"/>
      </svg>
    </div>

    <h1>FlowShift Manager Support</h1>
    <p class="subtitle">We're here to help</p>

    <div class="contact-card">
      <h2>Email Support</h2>
      <a href="mailto:support@pymesoft.site">support@pymesoft.site</a>
      <p>We typically respond within 24-48 hours</p>
    </div>

    <div class="faq">
      <h2>Frequently Asked Questions</h2>

      <div class="faq-item">
        <h3>How do I reset my password?</h3>
        <p>On the login screen, tap "Forgot Password" and enter your email address. You'll receive a link to reset your password.</p>
      </div>

      <div class="faq-item">
        <h3>How do I invite team members?</h3>
        <p>Go to Settings → Team → Invite Members. You can send invite links via email or share them directly.</p>
      </div>

      <div class="faq-item">
        <h3>How do I delete my account?</h3>
        <p>Go to Settings → Delete Account. Your data will be permanently removed within 30 days. <a href="/privacy/flowshift-manager/delete-account">Learn more</a></p>
      </div>

      <div class="faq-item">
        <h3>Is my data secure?</h3>
        <p>Yes! We use industry-standard encryption and security practices. Read our <a href="/privacy/flowshift-manager">Privacy Policy</a> for details.</p>
      </div>
    </div>

    <p class="footer">© 2026 PYMESOFT LLC. All rights reserved.</p>
  </div>
</body>
</html>
  `);
});

export default router;
