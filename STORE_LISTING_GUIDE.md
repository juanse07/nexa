# Nexa Store Listing Guide

_Last updated: February 2025_

This guide consolidates the assets, messaging, and metadata you need to prepare polished listings for the Apple App Store and Google Play Store.

---

## 1. Branding Snapshot
- **Product name:** Nexa – Event Staffing Manager
- **One-line value prop:** “Create, staff, and run hospitality events with AI-assisted scheduling.”
- **Primary audience:** Catering companies, hospitality staffing agencies, event managers, on-site supervisors.

---

## 2. Title, Subtitle, and Short Description

### 2.1 Apple App Store
- **Title (30 char max):** “Nexa Event Staffing”
- **Subtitle (30 char max):** “AI-powered event scheduling”
- **Promotional Text (170 char max):** “Draft events from PDFs in minutes, assign staff, and approve hours on-site.”

### 2.2 Google Play Store
- **App Name (30 char max):** “Nexa Event Staffing”
- **Short Description (80 char max):** “AI event creation, staff scheduling, timesheet approvals—built for hospitality teams.”

> **Tip:** Localize the subtitle/short description for additional markets if needed.

---

## 3. Full Description Templates

### 3.1 Apple App Store – Description (4,000 char max)
```
Nexa is the all-in-one event staffing platform for catering and hospitality teams. Turn sign-in sheets, proposals, or PDFs into staffing-ready events in minutes with AI powered extraction. Manage clients, assign roles, approve hours, and keep field teams synced anywhere.

HIGHLIGHTS
• AI Document Extraction – Upload PDFs or photos and Nexa maps the details into structured events.
• Manual Event Builder – Create drafts, define venues, roles, and pricing with powerful validation.
• Smart Staffing – Match staff to roles, track certifications, and monitor availability from one view.
• Hours Approval – Capture sign-in sheets, extract worked hours, and submit approvals instantly.
• Delta Sync – Keep web and mobile in sync even on spotty networks with bandwidth-saving updates.
• Secure Access – Google and Apple sign-in, role-based permissions, audit-ready logs.

Perfect for: catering companies, hospitality staffing agencies, venue operators, and event coordinators.

Need support? Visit https://app.nexapymesoft.com/support or email support@nexapymesoft.com.
```

### 3.2 Google Play Store – Long Description (4,000 char max)
```
Nexa gives hospitality and catering teams the tools to run flawless events. Upload your sign-in sheet or proposal, let AI extract the details, and assign staff with confidence. Whether you are prepping a gala, running multiple weddings, or closing out timesheets after service, Nexa keeps managers and teams aligned.

Key Capabilities:
• AI-powered event creation from PDFs, images, or manual entry
• Staff role assignments with availability, certifications, and call times
• Client, tariff, and catalog management for repeatable pricing
• Hours approval with OCR-powered timesheet extraction
• Real-time updates with delta sync for low-bandwidth environments
• Secure Google and Apple authentication plus granular permissions

Built specifically for catering companies, hospitality staffing firms, and on-site supervisors who need reliable scheduling in the field.

Support: https://app.nexapymesoft.com/support • Email: support@nexapymesoft.com
```

---

## 4. ASO Keyword Suggestions
- event staffing, catering staff, hospitality scheduling, AI staffing, timesheet approval, shift management, event planner, team scheduling, workforce automation, catering manager, staffing roster, event assignments
- iOS metadata also accepts locale-specific keyword fields (100 characters). Suggested set: `event staffing,catering,hospitality,AI scheduling,timesheets,shift manager,venue`.

---

## 5. Screenshot Requirements & Recommendations

### 5.1 Apple App Store
Capture key flows with clean device frames and short captions (“Extract event in seconds”, “Approve hours on-site”).

| Device Class | Required? | Resolution (px) | Notes |
| --- | --- | --- | --- |
| 6.7" iPhone (iPhone 15 Pro Max, etc.) | Required | 1284 × 2778 | Portrait recommended |
| 6.5" iPhone (iPhone 11 Pro Max) | Required | 1242 × 2688 | Can reuse scaled 6.7" shots |
| 5.5" iPhone (iPhone 8 Plus) | Required for clear coverage | 1242 × 2208 | Use @3x assets reused |
| 12.9" iPad Pro | Optional but encouraged | 2048 × 2732 | Highlight staff assignment dashboard |

> **Tip:** Use a consistent purple gradient background to match the in-app theme.

### 5.2 Google Play Store
| Form Factor | Count | Minimum Resolution | Orientation |
| --- | --- | --- | --- |
| Phone (6.5" class) | At least 3 (max 8) | 1080 × 1920 | Portrait |
| 7" Tablet | Optional | 1200 × 1920 | Landscape or portrait |
| 10" Tablet | Optional | 1600 × 2560 | Landscape preferred |

### 5.3 Feature Graphic (Android)
- Size: 1024 × 500 px (PNG or JPG)
- Concept: “Upload → Assign → Approve” with the Nexa logo and gradient background.

### 5.4 App Preview / Promo Video (Optional)
- **App Store:** 15–30 second portrait video showing AI extraction and staffing assignment.
- **Google Play:** 30 second landscape video uploaded to YouTube. Reuse existing marketing footage if available.

---

## 6. Icon, Logo, and Branding Assets
- Use existing assets in `assets/logo.png` and `assets/logo_padded_small.png`.
- Maintain the primary colors: Indigo `#6366F1`, Purple `#430172`.
- Ensure rounded corners and safe area padding comply with platform guidelines.

---

## 7. Categories & Ratings
- **Apple App Store Primary Category:** Business
- **Secondary Category:** Productivity (optional)
- **Google Play Category:** Business
- **Content Rating:** 4+ (Apple) / “Everyone” or “Everyone 10+” (Google) – no mature content.
- **Privacy Nutrition Label (iOS):** “Data used to provide the service” (events, identifiers) with no tracking.

---

## 8. Support & Compliance Links
- **Support URL:** https://app.nexapymesoft.com/support (or a dedicated knowledge base page)
- **Marketing Website:** https://nexapymesoft.com
- **Privacy Policy:** Link to `https://nexapymesoft.com/privacy` once `PRIVACY_POLICY.md` is hosted (or use GitHub Pages).
- **Terms of Service:** Ensure a public URL is available before submission.

---

## 9. Localization Roadmap (Optional)
- Prioritize Spanish (es) and French (fr) for North American hospitality teams.
- Translate title, subtitle, short description, long description, and screenshots captions.
- Re-run ASO keyword research in each locale.

---

## 10. Submission Checklist
1. Finalize icons and feature graphic.
2. Capture updated screenshots after QA on release builds.
3. Export privacy policy and host on a public URL.
4. Verify in-app purchase settings (none currently).
5. Run `build_ios_release.sh` or `build_android_release.sh` to produce store binaries.
6. Prepare test accounts for App Review / Play Console’s testers.
7. Fill out App Store “App Privacy” questionnaire and Play Console “Data safety” form using the privacy policy as source.

Use this guide as the master reference when preparing store metadata and creative assets. Update it whenever app messaging or feature scope changes.
