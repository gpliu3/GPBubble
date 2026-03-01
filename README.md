# GP Bubble

A delightful iOS todo app where tasks float as interactive bubbles. Pop them to complete, watch them rise throughout the day, and keep your tasks organized with a playful, intuitive interface.

## Features

### Bubble-Based Task Visualization
- **Dynamic Sizing**: Bubble size reflects task effort (5 min and up, including multi-hour tasks)
- **Smart Ordering**: Tasks arranged by priority and due time
- **Floating Animation**: Bubbles gently bob and rise as the day progresses
- **Satisfying Interactions**: Pop bubbles with delightful animations and haptic feedback
- **Recurring Indicator**: Two-line mark at the bottom of bubbles distinguishes recurring tasks

### Flexible Task Management
- **One-off Tasks**: Set specific deadlines with "Before" or "On" due date types
- **Recurring Tasks**: Daily, weekly, or monthly recurrence with optional specific times
- **Priority Levels**: 5 priority levels with color-coded indicators (Low to Critical)
- **Effort Tracking**: Time-based effort estimates (5min, 15min, 30min, 1hr, 2hr, plus custom X-hour wheel)
- **Pending List View**: Review every active task in a single list with quick swipe-to-complete and tap-to-edit actions
- **Past Due View**: Dedicated tab for overdue tasks, sorted by the same priority/urgency rules

### Advanced Monthly Recurrence (Outlook-style)
- **Specific Day**: Repeat on a specific day of the month (e.g., every 5th, 15th, or last day)
- **Nth Weekday**: Repeat on a specific weekday of a specific week (e.g., 3rd Wednesday, last Friday)
- **Times Per Month**: Flexible "X times per month" without specifying exact days

### Date Navigation
- **Swipe Navigation**: Swipe left/right to view tasks for different days
- **Date Picker**: Tap the date header to jump to any date
- **Quick Return**: "Today" button to quickly return to current day
- **Future Planning**: View and manage tasks scheduled for future dates

### Smart Notifications
- **Customizable Reminders**: 1-4 daily reminders with custom times
- **Task Lists**: Notifications show actual task titles
- **Time-Sensitive**: Uses iOS time-sensitive notifications for important tasks
- **Auto Badge Clear**: Badge clears when app is opened

### User Experience
- **Undo Support**: 3-second undo window after completing tasks
- **Sound & Haptics**: Satisfying audio and tactile feedback
- **Completed Tasks View**: Review your accomplishments with filtering options
- **Modern Task Editor**: Card-based add/edit sheets with denser spacing and better Zoom mode readability
- **Zoom Mode Support**: UI adapts to iPhone's Zoom display accessibility setting
- **Localization**: Full support for multiple languages including English, Chinese (Simplified & Traditional), Japanese, Korean, Spanish, French, German, and Portuguese
- **Refined Visual Theme**: Softer gradients, cleaner card surfaces, and unified accent colors across tabs

### Time-Based UI
- **Day Progress Indicator**: Background gradient changes from morning to evening
- **Rising Bubbles**: Tasks float higher as the day progresses (6 AM to 10 PM)
- **Visual Time Awareness**: Due time affects bubble positioning

## Requirements

- iOS 18.6 or later
- iPhone or iPad

## Tech Stack

- **Framework**: SwiftUI
- **Persistence**: SwiftData
- **Notifications**: UserNotifications (UNUserNotificationCenter)
- **Audio**: AVFoundation
- **Localization**: String Catalogs (10+ languages)
- **Architecture**: MVVM with @Observable and Combine

## Project Structure

```
GPBubble/
├── Models/
│   └── TaskItem.swift          # Core task model with SwiftData
├── Views/
│   ├── MainBubbleView.swift    # Main bubble interface with date navigation
│   ├── BubbleView.swift        # Individual bubble component
│   ├── BubblePopAnimation.swift # Pop animation effects
│   ├── AddTaskSheet.swift      # New task creation with monthly patterns
│   ├── EditTaskSheet.swift     # Task editing
│   ├── PendingTasksListView.swift # All active tasks in list form
│   ├── CompletedTasksView.swift # Completed tasks history
│   └── SettingsView.swift      # App settings
├── Utilities/
│   ├── NotificationManager.swift # Notification scheduling
│   ├── SoundManager.swift       # Audio playback
│   ├── LocalizationManager.swift # Language management
│   └── AppDelegate.swift        # App lifecycle & badge management
└── Resources/
    ├── Sounds/                  # Audio files
    └── Localizations/          # String catalogs (en, zh-Hans, zh-Hant, ja, ko, es, fr, de, pt-BR)
```

## Key Algorithms

### Bubble Sizing
```swift
// Effort-based sizing with square root scaling
var bubbleSize: Double {
    sqrt(effort)
}

var diameter: CGFloat {
    let baseSize: CGFloat = 62
    let scaleFactor: CGFloat = 9
    let size = baseSize + CGFloat(bubbleSize) * scaleFactor
    return min(max(size, 65), 165)
}
```

### Task Sorting
Tasks are scored based on:
- **Priority**: 2000-10000 points (2000 per priority level, ensures priority dominates urgency bonuses)
- **Due Today**: Earlier times get higher scores (0-500 bonus)
- **Overdue**: Exponential urgency penalties
- **"Before" Type**: Urgency increases as deadline approaches
- **Age**: Slight boost for older tasks without due dates

### Task Visibility
- **One-off "On" type**: Shows only on the due date
- **One-off "Before" type**: Shows from creation until end of due date day
- **Recurring**: Shows only on scheduled occurrence days
- **No due date**: Shows only on today's view

### Monthly Recurrence Patterns
- **Day of Month**: Find next occurrence of specific day, handling month length variations
- **Nth Weekday**: Calculate nth occurrence of a weekday in a month (supports "last" option)
- **Times Per Month**: Space occurrences evenly throughout the month

## Getting Started

1. Clone the repository:
```bash
git clone https://github.com/gpliu3/GPBubble.git
cd GPBubble
```

2. Open in Xcode:
```bash
open GPBubble.xcodeproj
```

3. Build and run on your device or simulator (iOS 18.6+)

## Usage

### Creating Tasks
1. Tap the **+** button in the bottom-right corner
2. Enter task details:
   - **Title**: What needs to be done
   - **Priority**: Urgency level (1-5)
   - **Time needed**: Estimated effort
   - **One-off task**: Set date/time and choose "Before" or "On" type
   - **Recurring task**: Choose frequency (Daily/Weekly/Monthly)
     - Weekly: Select specific days or "X times per week"
     - Monthly: Choose pattern - specific day, nth weekday, or X times per month

### Navigating Dates
- **Swipe left**: View next day's tasks
- **Swipe right**: View previous day's tasks
- **Tap date**: Open calendar picker to jump to any date
- **Tap "Today"**: Return to current day (appears when viewing other dates)
- **Automatic Day Rollover**: If the app stays open overnight, the Today view automatically refreshes to the new day
- **Pending Tab**: Review all active tasks in a single scrollable list
- **Past Due Tab**: Access overdue tasks separately from Pending/Done

### Completing Tasks
- **Tap** a bubble to complete the task
- Watch the satisfying pop animation
- **Undo** within 3 seconds if needed

### Managing Completed Tasks
- Navigate to **Done** screen from tab bar
- Filter by: Today, This Week, This Month, or All Time
- **Long press** to edit completed tasks
- **Swipe left** to delete
- **Swipe right** to restore (if not past due)

### Managing Past Due Tasks
- Navigate to **Past Due** screen from tab bar
- View all overdue tasks sorted by the same priority/urgency logic as bubbles
- **Tap** a bubble to complete
- **Long press** a bubble to edit
- Bubble layout is static (no time-of-day rising animation)

### Managing Pending Tasks
- Navigate to **Pending** screen from tab bar
- View overdue, today, upcoming, and someday tasks in one place
- **Tap** a row to edit a task
- **Swipe** to complete a task without opening the editor

### Settings
- **Notifications**: Enable and configure 1-4 daily reminders
- **Language**: Choose from 10+ supported languages
- **Permissions**: Manage notification access

## Design Philosophy

GP Bubble transforms the mundane task list into a playful, engaging experience:

- **Visual Metaphor**: Bubbles represent tasks floating to the surface of your attention
- **Size as Priority**: Bigger bubbles (longer tasks) naturally draw more attention
- **Time as Motion**: Bubbles rise throughout the day, creating urgency
- **Completion as Release**: Popping bubbles provides satisfying closure
- **Color as Signal**: Priority colors provide instant visual feedback

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with SwiftUI and SwiftData
- Developed with assistance from Claude
- Inspired by the need for a more joyful task management experience

## Contact

For questions, suggestions, or feedback, please open an issue on GitHub.

---

Made with care
