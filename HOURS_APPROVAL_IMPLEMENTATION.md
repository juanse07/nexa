# Hours Approval System - Implementation Summary

## Overview
Successfully implemented an AI-powered hours approval system that allows managers to:
1. Upload photos of client sign-in/out sheets
2. Use OpenAI to automatically extract staff hours from photos
3. Review and edit extracted hours
4. Submit hours for approval (individual or bulk)

---

## Backend Changes

### 1. Updated Event Model (`backend/src/models/event.ts`)
Added fields to track hours approval workflow:

**AttendanceSession** interface extended with:
- `sheetSignInTime`, `sheetSignOutTime` - Official times from client sheet
- `approvedHours` - Final approved hours
- `status` - Workflow state: 'clocked' | 'pending_sheet' | 'sheet_submitted' | 'approved' | 'disputed'
- `approvedBy`, `approvedAt` - Approval tracking
- `managerNotes`, `discrepancyNote` - Documentation

**EventDocument** interface extended with:
- `hoursStatus` - Event-level status
- `signInSheetPhotoUrl` - Photo storage
- `hoursSubmittedBy/At`, `hoursApprovedBy/At` - Audit trail

### 2. New API Endpoints (`backend/src/routes/events.ts`)

**POST `/events/:id/analyze-sheet`**
- Accepts: `imageBase64`, `openaiApiKey`
- Uses OpenAI GPT-4o-mini vision model
- Extracts staff names, roles, sign-in/out times
- Returns: JSON with extracted staff hours

**POST `/events/:id/submit-hours`**
- Accepts: Array of staff hours, photo URL, submitter
- Updates each staff member's attendance with sheet data
- Marks event as 'sheet_submitted'

**POST `/events/:id/approve-hours/:userKey`**
- Approve hours for individual staff member
- Accepts: approved hours, approver name, optional notes
- Marks attendance as 'approved'

**POST `/events/:id/bulk-approve-hours`**
- Bulk approve all submitted hours for an event
- Marks all staff with status 'sheet_submitted' as 'approved'
- Returns count of approved staff

---

## Frontend Changes (Main Nexa App)

### 1. Timesheet Extraction Service
**Location:** `lib/features/hours_approval/services/timesheet_extraction_service.dart`

Features:
- Analyzes sign-in sheet photos using OpenAI
- Submits hours to backend
- Individual and bulk approval methods
- Auto-calculates hours from time strings
- Parses 12-hour AM/PM format

### 2. Hours Approval Screen
**Location:** `lib/features/hours_approval/presentation/hours_approval_screen.dart`

A complete UI for the hours approval workflow:

**Features:**
- 📸 Take photo or upload from gallery
- 🤖 AI analysis with loading states
- ✏️ Edit extracted hours (dialog with fields for times, hours, notes)
- 👁️ Review staff hours with visual cards
- ⏰ Auto-calculate hours from sign-in/out times
- ✅ Individual or bulk approval
- 🚨 Error handling and user feedback

**UI Components:**
- Event info card (name, client, date)
- Photo upload/preview section
- AI analysis button
- Extracted hours list with edit capability
- Action buttons: "Submit for Review" and "Bulk Approve"

---

## How It Works

### Workflow:

1. **Manager completes event** → Opens Hours Approval Screen

2. **Upload Sheet Photo:**
   - Take photo with camera or upload from gallery
   - Photo displays with preview

3. **AI Analysis:**
   - Tap "Analyze with AI"
   - OpenAI extracts:
     - Staff names
     - Roles
     - Sign-in times
     - Sign-out times
     - Any notes on sheet

4. **Review & Edit:**
   - See all extracted hours in cards
   - Auto-calculated total hours shown
   - Tap edit icon to manually adjust any field
   - Add manager notes if needed

5. **Approval:**
   - **Submit for Review:** Saves hours as 'sheet_submitted' status
   - **Bulk Approve:** Submits AND approves all hours at once

6. **Backend Processing:**
   - Hours stored in attendance session
   - Discrepancies between clock-in and sheet tracked
   - Audit trail maintained (who/when approved)

---

## AI Prompt Design

The OpenAI prompt is specifically designed for timesheet extraction:
- Provides event context (name, expected staff)
- Instructs on exact JSON format needed
- Handles both printed and handwritten sheets
- Extracts times in 12-hour AM/PM format
- Captures any notes or annotations

---

## Data Flow

```
Client Sign-In Sheet (Paper)
    ↓ (Photo)
Manager's Phone/Tablet
    ↓ (Upload)
Hours Approval Screen
    ↓ (Base64)
Backend: /analyze-sheet
    ↓ (OpenAI API)
GPT-4o-mini Vision
    ↓ (Extracted JSON)
Frontend: Review UI
    ↓ (Edit if needed)
Backend: /submit-hours
    ↓
MongoDB: Event.accepted_staff.attendance
    ↓ (Optional)
Backend: /bulk-approve-hours
    ↓
Status: APPROVED ✅
```

---

## Usage Example

### To use the Hours Approval Screen:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => HoursApprovalScreen(
      event: eventMap, // Your event data
    ),
  ),
);
```

### API Example (cURL):

```bash
# Analyze sheet
curl -X POST http://localhost:4000/api/events/{eventId}/analyze-sheet \
  -H "Content-Type: application/json" \
  -d '{
    "imageBase64": "...",
    "openaiApiKey": "sk-..."
  }'

# Bulk approve
curl -X POST http://localhost:4000/api/events/{eventId}/bulk-approve-hours \
  -H "Content-Type: application/json" \
  -d '{
    "approvedBy": "Manager Name"
  }'
```

---

## Key Features

✅ **AI-Powered Extraction** - Automatic OCR using OpenAI Vision
✅ **Manual Override** - Edit any field before approval
✅ **Bulk Approval** - Approve all hours at once
✅ **Individual Approval** - Approve staff one by one
✅ **Audit Trail** - Track who approved what and when
✅ **Discrepancy Tracking** - Compare clock vs sheet times
✅ **Photo Documentation** - Store sign-in sheet photo
✅ **Auto-Calculate Hours** - Smart time parsing and calculation
✅ **Error Handling** - Graceful failures with user feedback

---

## Next Steps

### Recommended Enhancements:

1. **User Authentication**
   - Replace hardcoded 'Manager' with actual logged-in user
   - Add user permissions (who can approve hours)

2. **Staffside App Integration**
   - Show approval status on staff's "My Events" tab
   - Badges: "Pending Approval", "Approved", "Disputed"
   - Allow staff to view approved hours and calculated pay

3. **Payroll Export**
   - Export approved hours to CSV for payroll
   - Integration with payroll systems (QuickBooks, etc.)
   - Generate timesheet reports

4. **Notifications**
   - Notify staff when hours are approved
   - Alert managers when events need hour approval
   - Weekly digest of pending approvals

5. **Cloud Storage**
   - Upload sheet photos to cloud storage (Firebase, S3)
   - Currently using local file paths
   - Better for multi-device access

6. **Analytics Dashboard**
   - Hours pending approval count
   - Average processing time
   - Discrepancy statistics

---

## Files Modified/Created

### Backend:
- `backend/src/models/event.ts` - Updated model
- `backend/src/routes/events.ts` - New endpoints

### Frontend:
- `lib/features/hours_approval/services/timesheet_extraction_service.dart` - NEW
- `lib/features/hours_approval/presentation/hours_approval_screen.dart` - NEW
- `pubspec.yaml` - Added image_picker dependency

---

## Testing

### Backend:
```bash
cd backend
npm run build  # ✅ Compiles successfully
```

### Frontend:
```bash
cd /path/to/nexa
flutter pub get  # ✅ Dependencies installed
flutter analyze lib/features/hours_approval/  # ✅ No errors
```

---

## Dependencies Added

- `image_picker: ^1.1.2` - Camera/gallery image selection

Existing dependencies used:
- OpenAI API (via your OPENAI_API_KEY)
- http package
- Flutter material design

---

## Security Considerations

⚠️ **Important:**
- OpenAI API key is passed from frontend to backend
- Consider moving API key to backend-only
- Sheet photos contain sensitive data - ensure proper access control
- Approved hours affect payroll - implement multi-level approval for large amounts

---

## Support

For questions or issues:
1. Check this document
2. Review code comments in implementation files
3. Test with sample events first
4. Verify OpenAI API key is configured correctly

---

**Implementation Complete! 🎉**

The hours approval system is ready to use. Simply navigate to the `HoursApprovalScreen` with an event object to start approving hours.
