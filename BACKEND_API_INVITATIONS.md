# Backend API Documentation - Event Invitation System

## Overview
This document describes the backend API endpoints and socket events required to support the event invitation feature in the chat system.

---

## REST API Endpoints

### 1. Send Event Invitation Message

**Endpoint:** `POST /chat/conversations/:targetId/messages`

**Description:** Sends an event invitation message to a user

**Headers:**
```
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

**Request Body:**
```json
{
  "message": "You've been invited to Summer Gala as Lead Server",
  "messageType": "eventInvitation",
  "metadata": {
    "eventId": "507f1f77bcf86cd799439011",
    "roleId": "507f1f77bcf86cd799439012",
    "status": "pending"
  }
}
```

**Response:** `201 Created`
```json
{
  "message": {
    "id": "507f1f77bcf86cd799439013",
    "conversationId": "507f1f77bcf86cd799439014",
    "senderType": "manager",
    "senderName": "John Doe",
    "senderPicture": "https://...",
    "message": "You've been invited to Summer Gala as Lead Server",
    "messageType": "eventInvitation",
    "metadata": {
      "eventId": "507f1f77bcf86cd799439011",
      "roleId": "507f1f77bcf86cd799439012",
      "status": "pending"
    },
    "readByManager": false,
    "readByUser": false,
    "createdAt": "2025-10-19T10:30:00.000Z"
  }
}
```

---

### 2. Respond to Event Invitation

**Endpoint:** `POST /chat/invitations/:messageId/respond`

**Description:** Staff member accepts or declines an event invitation

**Headers:**
```
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

**Request Body:**
```json
{
  "accept": true,
  "eventId": "507f1f77bcf86cd799439011",
  "roleId": "507f1f77bcf86cd799439012"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Invitation accepted",
  "updatedMessage": {
    "id": "507f1f77bcf86cd799439013",
    "metadata": {
      "eventId": "507f1f77bcf86cd799439011",
      "roleId": "507f1f77bcf86cd799439012",
      "status": "accepted",
      "respondedAt": "2025-10-19T10:35:00.000Z"
    }
  },
  "updatedEvent": {
    "_id": "507f1f77bcf86cd799439011",
    "roles": [
      {
        "_id": "507f1f77bcf86cd799439012",
        "role_name": "Lead Server",
        "confirmed_user_ids": ["user_123"]
      }
    ]
  }
}
```

**Backend Actions on Accept:**
1. Update message metadata:
   - Set `status` to "accepted"
   - Add `respondedAt` timestamp
2. Update Event:
   - Find the specific role in `event.roles` array
   - Add `userId` to `role.confirmed_user_ids`
3. Emit socket event to manager
4. Send confirmation message in chat (optional)

**Backend Actions on Decline:**
1. Update message metadata:
   - Set `status` to "declined"
   - Add `respondedAt` timestamp
2. Emit socket event to manager
3. Do NOT modify event roster

---

### 3. Get Event Details

**Endpoint:** `GET /events/:eventId`

**Description:** Fetch full event details for rendering invitation card

**Headers:**
```
Authorization: Bearer <JWT_TOKEN>
```

**Response:** `200 OK`
```json
{
  "_id": "507f1f77bcf86cd799439011",
  "title": "Summer Gala 2024",
  "client_name": "Bluebird Catering",
  "start_date": "2025-06-15T18:00:00.000Z",
  "end_date": "2025-06-15T23:00:00.000Z",
  "venue_name": "Grand Ballroom",
  "roles": [
    {
      "_id": "507f1f77bcf86cd799439012",
      "role_id": "507f1f77bcf86cd799439012",
      "role_name": "Lead Server",
      "quantity": 5,
      "confirmed_user_ids": ["user_123", "user_456"],
      "rate": 28.50
    }
  ]
}
```

---

## Socket.IO Events

### 1. New Invitation Message

**Event:** `chat:message`

**Direction:** Server → Client (Staff)

**When:** Manager sends an event invitation

**Payload:**
```json
{
  "id": "507f1f77bcf86cd799439013",
  "conversationId": "507f1f77bcf86cd799439014",
  "senderType": "manager",
  "senderName": "John Doe",
  "message": "You've been invited to Summer Gala as Lead Server",
  "messageType": "eventInvitation",
  "metadata": {
    "eventId": "507f1f77bcf86cd799439011",
    "roleId": "507f1f77bcf86cd799439012",
    "status": "pending"
  },
  "createdAt": "2025-10-19T10:30:00.000Z"
}
```

---

### 2. Invitation Response Notification

**Event:** `invitation:responded`

**Direction:** Server → Client (Manager)

**When:** Staff member accepts/declines an invitation

**Payload:**
```json
{
  "messageId": "507f1f77bcf86cd799439013",
  "conversationId": "507f1f77bcf86cd799439014",
  "status": "accepted",
  "respondedAt": "2025-10-19T10:35:00.000Z",
  "userId": "user_123",
  "userName": "Jane Smith",
  "eventId": "507f1f77bcf86cd799439011",
  "roleId": "507f1f77bcf86cd799439012"
}
```

**Client Behavior:**
- Manager app shows notification: "Jane Smith accepted the invitation!"
- Reload messages to show updated card with green "Accepted" badge
- Update event roster count in real-time

---

## Database Schema Updates

### Message Collection

```javascript
{
  _id: ObjectId,
  conversationId: ObjectId,
  senderType: String, // 'manager' | 'user'
  senderName: String,
  senderPicture: String,
  message: String,
  messageType: String, // 'text' | 'eventInvitation'  <-- NEW
  metadata: {          // <-- NEW
    eventId: ObjectId,
    roleId: ObjectId,
    status: String, // 'pending' | 'accepted' | 'declined'
    respondedAt: Date
  },
  readByManager: Boolean,
  readByUser: Boolean,
  createdAt: Date
}
```

### Event Collection (Existing)

```javascript
{
  _id: ObjectId,
  title: String,
  client_name: String,
  start_date: Date,
  end_date: Date,
  venue_name: String,
  roles: [
    {
      _id: ObjectId,
      role_id: ObjectId,
      role_name: String,
      quantity: Number,
      confirmed_user_ids: [String], // <-- Updated on accept
      rate: Number
    }
  ]
}
```

---

## Error Handling

### Invalid Event/Role

**Response:** `404 Not Found`
```json
{
  "error": "Event not found",
  "code": "EVENT_NOT_FOUND"
}
```

### Already Responded

**Response:** `400 Bad Request`
```json
{
  "error": "Invitation already responded to",
  "code": "INVITATION_ALREADY_RESPONDED",
  "currentStatus": "accepted"
}
```

### Event Full

**Response:** `400 Bad Request`
```json
{
  "error": "Event role is already full",
  "code": "EVENT_ROLE_FULL",
  "role": "Lead Server",
  "filled": 5,
  "needed": 5
}
```

---

## Testing Checklist

### Manager Flow
- [ ] Click invitation icon in chat
- [ ] Search for events
- [ ] Select event and role
- [ ] Send invitation
- [ ] See card in chat with "Waiting for response..."
- [ ] Receive real-time notification when staff responds
- [ ] Card updates to show accepted/declined status

### Staff Flow
- [ ] Receive push notification
- [ ] Open chat and see invitation card
- [ ] View all event details
- [ ] Click Accept → See green success message
- [ ] Card updates to show "Accepted" status
- [ ] Click Decline → Confirm dialog appears
- [ ] Card updates to show "Declined" status
- [ ] Event roster updated (on accept only)

### Edge Cases
- [ ] Accept invitation for event that just became full
- [ ] Respond to invitation that was already responded to
- [ ] Invitation for deleted event
- [ ] Invitation for deleted role
- [ ] Network failure during response
- [ ] App restart with pending invitation

---

## Security Considerations

1. **Authorization:**
   - Only managers can send invitations
   - Only the invited staff member can respond
   - Validate JWT token on all endpoints

2. **Validation:**
   - Verify eventId exists and is accessible
   - Verify roleId exists within event
   - Check role capacity before accepting
   - Prevent duplicate responses

3. **Rate Limiting:**
   - Limit invitation sends per manager (e.g., 100/hour)
   - Limit responses per user (prevent spam)

---

## Performance Optimizations

1. **Caching:**
   - Cache event details for 5 minutes
   - Invalidate cache on event updates

2. **Indexing:**
   - Index `messageType` field for faster queries
   - Index `metadata.eventId` for invitation lookups
   - Index `metadata.status` for filtering

3. **Socket Rooms:**
   - Join managers to conversation-specific rooms
   - Emit `invitation:responded` only to relevant manager

---

## Monitoring & Analytics

Track these metrics:
- Invitation send rate
- Acceptance rate (%)
- Response time (minutes to accept/decline)
- Most invited events
- Most responsive staff members
- Failed invitations (errors)

**Recommended Events:**
```javascript
// Analytics events to track
analytics.track('invitation_sent', {
  eventId, roleId, targetUserId, managerId
});

analytics.track('invitation_responded', {
  messageId, eventId, roleId, userId, accepted, responseTimeMinutes
});

analytics.track('invitation_error', {
  error, eventId, userId, step
});
```

---

## Implementation Priority

1. ✅ **Phase 1:** Basic send/respond endpoints
2. ✅ **Phase 2:** Socket events for real-time updates
3. ⏳ **Phase 3:** Event roster auto-update on accept
4. ⏳ **Phase 4:** Automatic confirmation messages
5. ⏳ **Phase 5:** Push notifications
6. ⏳ **Phase 6:** Analytics integration

---

## Support & Troubleshooting

### Common Issues

**Q: Invitation card shows "Event not found"**
- Check if event still exists in database
- Verify user has permission to view event
- Check eventId format is correct

**Q: Accept button doesn't work**
- Check if role is already full
- Verify user authentication
- Check network connectivity
- Review server logs for errors

**Q: Manager doesn't receive response notification**
- Verify socket connection is active
- Check socket room membership
- Ensure `invitation:responded` event is emitted
- Review client-side socket listeners

---

## Contact

For backend implementation questions:
- Review this documentation
- Check existing chat message endpoints
- Follow the same patterns for authentication/authorization

Frontend is fully implemented and ready to integrate!
