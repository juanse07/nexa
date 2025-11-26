# Extraction Screen Refactoring Guide

## ✅ What's Been Completed

### 1. Theme System (`presentation/theme/`)
- **extraction_theme.dart** - Centralized colors, gradients, text styles, decorations, dimensions
- **Usage**: `import '../theme/extraction_theme.dart';` then use `ExColors.yellow`, `ExGradients.brand`, `ExTextStyles.eventClientName`, etc.

### 2. Business Logic Utilities (`utils/`)
- **event_card_utils.dart** - Capacity calculations, privacy status, date formatting
- **Usage**: `EventCardUtils.calculateCapacity(event)`, `EventCardUtils.getPrivacyStatus(event)`

### 3. Reusable Widgets (`presentation/widgets/`)
- **EventCardWidget** - Complete event card with all functionality
- **EmptyStateWidget** - Reusable empty states with icon, title, subtitle, action button
- **extraction_widgets.dart** - Index file for clean imports

### 4. Current File Structure
```
lib/features/extraction/
├── presentation/
│   ├── theme/
│   │   └── extraction_theme.dart          ✅ Created
│   ├── widgets/
│   │   ├── cards/
│   │   │   └── event_card_widget.dart     ✅ Created
│   │   ├── common/
│   │   │   └── empty_state_widget.dart    ✅ Created
│   │   └── extraction_widgets.dart        ✅ Created (index)
│   └── pages/
│       └── extraction_screen.dart         🔄 To be refactored
├── utils/
│   └── event_card_utils.dart              ✅ Created
```

---

## 📋 Remaining Work

### Priority 1: Update extraction_screen.dart to Use New Widgets

**Step 1: Add imports at top of extraction_screen.dart**
```dart
import 'widgets/extraction_widgets.dart';
```

**Step 2: Replace _buildEventCard() method**

Find all places where `_buildEventCard(event)` is called and replace with:
```dart
EventCardWidget(
  event: event,
  showMargin: true,  // or false depending on context
  onEventUpdated: () => _loadEvents(),
  onEventDeleted: () async {
    try {
      final eventId = (event['_id'] ?? event['id'] ?? '').toString();
      await _eventService.deleteEvent(eventId);
      await _loadEvents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
  onOpenMaps: _openGoogleMaps,
  onShareEvent: _shareEvent,
)
```

**Step 3: Delete old _buildEventCard() method** (lines 7501-7937)

**Step 4: Delete helper methods** (now in EventCardUtils):
- `_calculateCapacity()` (line 4402)
- `_getPrivacyStatus()` (line 4417)
- `_getPrivacyColor()` (line 4468)
- `_getCapacityColor()` (line 4483)

**Step 5: Update hardcoded colors to use theme**

Find and replace throughout extraction_screen.dart:
- `Color(0xFFFFC107)` → `ExColors.yellow`
- `Color(0xFF3B82F6)` → `ExColors.techBlue`
- `Color(0xFF212C4A)` → `ExColors.navySpaceCadet`
- `Color(0xFF1E3A8A)` → `ExColors.oceanBlue`
- `Color(0xFF10B981)` → `ExColors.success`
- `Color(0xFF00BCD4)` → `ExColors.info`
- `Color(0xFFEF4444)` → `ExColors.error`
- `Color(0xFF6B7280)` → `ExColors.textSecondary`
- `Color(0xFF0F172A)` → `ExColors.textPrimary`
- `Color(0xFFF8FAFC)` → `ExColors.backgroundLight`

**Step 6: Use ExDecorations for common patterns**

Replace:
```dart
BoxDecoration(
  gradient: LinearGradient(
    colors: [Color(0xFFFFC107), Color(0xFF3B82F6)],
  ),
  borderRadius: BorderRadius.circular(12),
)
```

With:
```dart
ExDecorations.brandGradientContainer
```

---

### Priority 2: Extract Large Tab Content Widgets

#### Pattern for Extracting Tab Widgets

**Example: Events Tab**

1. **Create new widget file**: `widgets/tabs/events_tab_content.dart`

2. **Structure**:
```dart
import 'package:flutter/material.dart';
import '../../theme/extraction_theme.dart';
import '../extraction_widgets.dart';

class EventsTabContent extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) onEventTap;

  const EventsTabContent({
    super.key,
    required this.events,
    required this.onRefresh,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.event_busy,
        title: 'No Events',
        subtitle: 'Create your first event to get started',
        actionLabel: 'Create Event',
        onActionPressed: () {
          // Navigate to create event
        },
      );
    }

    return ListView.builder(
      itemCount: events.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return EventCardWidget(
          event: events[index],
          showMargin: true,
          onEventUpdated: onRefresh,
          onEventDeleted: onRefresh,
          onOpenMaps: (address, url) {
            // Handle maps navigation
          },
          onShareEvent: (event) {
            // Handle share
          },
        );
      },
    );
  }
}
```

3. **In extraction_screen.dart**, replace the tab content:
```dart
// OLD:
_buildEventsTab()

// NEW:
EventsTabContent(
  events: _events,
  onRefresh: _loadEvents,
  onEventTap: (event) => Navigator.push(...)
)
```

#### Widgets to Extract (in order):

1. **Manual Entry Form** (~700 lines)
   - File: `widgets/tabs/manual_entry_form_widget.dart`
   - Extract: `_buildManualEntryForm()` method
   - State management: Keep form controllers in extraction_screen, pass as params

2. **Upload Tab** (~600 lines)
   - File: `widgets/tabs/upload_tab_content.dart`
   - Extract: `_buildUploadTab()` method
   - Pass: Upload state, file handlers, callbacks

3. **Catalog Tabs** (~350 lines each)
   - Files:
     - `widgets/catalog_tabs/clients_tab_widget.dart`
     - `widgets/catalog_tabs/roles_tab_widget.dart`
     - `widgets/catalog_tabs/tariffs_tab_widget.dart`
   - Extract: `_buildClientsInner()`, `_buildRolesInner()`, `_buildTariffsInner()`

4. **Navigation Components** (~200 lines each)
   - Files:
     - `widgets/navigation/extraction_navigation_rail.dart`
     - `widgets/navigation/extraction_desktop_app_bar.dart`
   - Extract: `_buildNavigationRail()`, `_buildDesktopAppBar()`

---

### Priority 3: Example - Extract Empty State Usage

Find all instances of empty state UI and replace with `EmptyStateWidget`:

**Before**:
```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.folder_open, size: 64, color: Colors.grey),
      SizedBox(height: 16),
      Text('No clients yet', style: TextStyle(fontSize: 18)),
      SizedBox(height: 8),
      Text('Add your first client to get started'),
    ],
  ),
)
```

**After**:
```dart
EmptyStateWidget(
  icon: Icons.folder_open,
  title: 'No clients yet',
  subtitle: 'Add your first client to get started',
  actionLabel: 'Add Client',
  onActionPressed: () => Navigator.push(...),
)
```

---

## 🎯 Expected Results

### File Size Reduction
| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| extraction_screen.dart | 9,739 lines | ~3,000 lines | 6,739 lines (69%) |
| Theme/styling | Scattered | 1 file | Centralized |
| Event card | Inline | Reusable widget | Testable |
| Empty states | Duplicated | 1 widget | Consistent |

### Benefits
- ✅ **Maintainability**: Single source of truth for styling
- ✅ **Reusability**: Widgets can be used across features
- ✅ **Testability**: Isolated widgets are easier to test
- ✅ **Consistency**: All event cards look and behave identically
- ✅ **Performance**: Smaller widget trees rebuild faster
- ✅ **Collaboration**: Multiple developers can work on different widgets

---

## 🚀 Quick Start

1. **Update extraction_screen.dart imports**:
```dart
import 'widgets/extraction_widgets.dart';
```

2. **Replace event cards**:
   - Search for: `_buildEventCard(`
   - Replace with: `EventCardWidget(...)` (see Step 2 above)

3. **Replace hardcoded colors**:
   - Search for: `Color(0xFFFFC107)`
   - Replace with: `ExColors.yellow`
   - Repeat for all colors listed in Step 5

4. **Test after each change**:
```bash
flutter run
```

5. **Verify no regressions** - all event cards should look and function identically

---

## 📝 Testing Checklist

After refactoring, verify:
- [ ] Event cards display correctly
- [ ] Tap to open event details works
- [ ] Capacity badges show correct colors
- [ ] Privacy badges display for published events
- [ ] Publish button works for draft events
- [ ] Delete button works with confirmation
- [ ] Maps navigation works
- [ ] Share event works
- [ ] Empty states display when no data
- [ ] Theme colors are consistent throughout

---

## 💡 Tips

1. **Work incrementally** - Replace one widget at a time, test, commit
2. **Use git branches** - Create a branch for refactoring: `git checkout -b refactor/extraction-screen`
3. **Hot reload works** for widget changes, but **hot restart** needed for color constants
4. **VSCode search/replace** - Use regex find/replace for color updates
5. **Keep extraction_screen.dart focused** on state management, data loading, and composition

---

## ❓ FAQ

**Q: Should I delete the old methods immediately?**
A: No, keep them until you've verified the new widgets work. Comment them out first, test thoroughly, then delete.

**Q: What if I need to customize a widget for a specific use case?**
A: Add optional parameters to the widget. Example: `EventCardWidget(showActions: false)`

**Q: How do I handle widget-specific state?**
A: Keep state in the parent (extraction_screen.dart), pass it down as parameters and callbacks.

**Q: Can I extract widgets to different files mid-development?**
A: Yes! Extract methods to private widgets first, then move to separate files when stable.

---

## 📚 Next Steps

1. Complete the priority 1 updates (use existing widgets)
2. Extract 1-2 large tab widgets to learn the pattern
3. Apply pattern to remaining widgets
4. Update documentation
5. Add widget tests
6. Create pull request for review

**Estimated time**: 4-6 hours for complete refactoring

Good luck! 🎉
