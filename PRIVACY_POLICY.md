# Nexa Privacy Policy

_Last updated: February 2025_

Nexa (“we”, “our”, or “us”) provides an event staffing management platform that helps catering and hospitality teams create events, schedule staff, and approve hours. This privacy policy explains what information we collect, why we collect it, how we use it, and the choices you have.

By using the Nexa mobile, tablet, or web application (collectively, the “App”), you agree to the practices described below. If you do not agree, please discontinue use of the App.

---

## 1. Information We Collect

We collect the minimum data required to deliver the App’s core functionality.

### 1.1 Account & Authentication Data
- Profile details provided by users and administrators (name, email, phone number).
- Role and certification information for staff members.
- Authentication tokens and identifiers received from Google Sign-In and Apple Sign-In.

### 1.2 Event & Staffing Data
- Event records including venue, schedule, client contacts, staffing requirements, and notes.
- Staff assignments, timesheets, approvals, and pay rate information.
- AI-assisted extraction drafts and uploads created through the document extraction workflow.

### 1.3 Uploaded Content
- Files supplied by users (PDFs, images, HEIC, etc.) for AI extraction of event data or timesheet analysis.
- Photos captured via the device camera or selected from the gallery for hours-approval workflows.

### 1.4 Location & Mapping Data
- Venue addresses, geocoordinates, and Places autocomplete selections used to plan events.
- Optional device location signals when users choose to autofill venue details.

### 1.5 Device & Usage Data
- Device model, operating system version, app version, and error logs to improve stability.
- Basic analytics about feature usage (e.g., extraction run counts) with no biometric or sensor data.

We do not knowingly collect information from children under 13 years of age.

---

## 2. How We Use Information

We use collected information to:
- Create, update, and manage event schedules and staffing assignments.
- Power AI document extraction, draft storage, and hours-approval automation.
- Authenticate users, maintain sessions, and secure access to role-based features.
- Provide push and email notifications about staffing changes or approvals (when enabled).
- Improve product performance, debug issues, and develop new features based on aggregate usage.
- Comply with legal obligations and enforce our Terms of Service.

---

## 3. Third-Party Services

We integrate with trusted partners to deliver the App:

| Service | Purpose | Data Shared |
| --- | --- | --- |
| **Google Sign-In** | User authentication (mobile/web) | OAuth tokens, email, profile name |
| **Apple Sign-In** | User authentication (iOS/web) | Apple token, anonymized email (if configured) |
| **Google Maps Platform** (Maps SDK, Places API) | Venue lookup, maps, autocomplete | Venue queries, approximate location context |
| **OpenAI API** | AI-powered extraction of event documents and sign-in sheets | Document or image content supplied by user, OpenAI API key |
| **Backend Services** (`https://api.nexapymesoft.com`) | Core API, delta synchronization, storage | Event data, user records, staffing details |

Each provider processes information according to its own privacy policy. We recommend reviewing their documentation for additional detail.

---

## 4. Data Storage & Retention

- **Local storage:** We keep authentication tokens in secure storage and cache draft data in SharedPreferences on the device so users can resume work offline. Clearing the app data removes these items.
- **Server storage:** Event data, staffing assignments, hours, and AI extraction results are stored on our managed infrastructure. We retain records for as long as needed to support ongoing business operations or as required by law.
- **Backups and logs:** We maintain encrypted backups and service logs with limited retention to support reliability and security audits.
- **Deletion:** When an organization requests deletion, associated records are removed or anonymized in accordance with applicable regulations.

---

## 5. User Rights & Controls

Depending on your jurisdiction, you may have rights to:
- Access, review, or export personal information stored about you.
- Request correction of inaccurate data.
- Ask for deletion of your profile or specific records (subject to contractual or legal obligations).
- Opt out of non-essential communications.
- Give or withdraw consent for AI-based processing features.

To exercise these rights, contact us using the information in Section 8. We may need to verify your identity before completing requests.

---

## 6. Security Measures

We implement technical and organizational safeguards to protect data, including:
- Transport Layer Security (TLS) for all API communication.
- Role-based access controls enforced by our backend and in-app permissions.
- Encrypted storage of sensitive tokens using platform-secure storage APIs.
- Auditing, logging, and monitoring for suspicious activity.
- Least-privilege access for team members with data access responsibilities.

Despite these measures, no method of transmission or storage is completely secure. If you suspect unauthorized access, please notify us immediately.

---

## 7. International Transfers

We operate primarily from the United States. If you access the App from other regions, your information may be transferred to, stored, and processed in the United States or any country where we or our service providers operate. We take appropriate steps to ensure such transfers comply with applicable data-protection laws.

---

## 8. Contact Information

Questions or privacy requests can be sent to:

```
Nexa Privacy Team
Email: support@nexapymesoft.com
Address: [Insert mailing address]
```

If you are acting on behalf of your organization, please include your company name and the nature of your request.

---

## 9. Changes to This Policy

We may update this privacy policy to reflect changes in our practices or applicable laws. When we make material changes, we will notify you through the App or by email and update the “Last updated” date at the top of this document. Continued use after the effective date constitutes acceptance of the revised policy.

---

## 10. Additional Resources

- `AI_CONTEXT.md` – Overview of application architecture and security layers.
- `DELTA_SYNC_QUICKSTART.md` – Details on data synchronization safeguards.
- `HOURS_APPROVAL_IMPLEMENTATION.md` – Technical description of the OpenAI integration.

Please review these documents for deeper technical context about how Nexa processes and protects information.
