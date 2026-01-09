# ARCHITECTURE_SCHEMA.md

# Juju Project Tracking App

## 🤖 How to Use This Documentation

**For AI Assistants and Developers:**

- **Data Model Reference**: Use this file to understand the exact structure of all business entities
- **Type Definitions**: All structs, enums, and their properties are defined here
- **Cross-Reference**: See ARCHITECTURE_RULES.md for architectural patterns and DATA_FLOW.yaml for how these data types flow through the system
- **Source of Truth**: All components (Views, ViewModels, Managers, Services) must use the types and properties defined here

**Key Relationships:**

- This file defines the DATA STRUCTURES used in the architecture from ARCHITECTURE_RULES.md
- All data_packet types in DATA_FLOW.yaml are defined in this file
- Component interactions in DATA_FLOW.yaml use these exact type definitions

**When making changes:**

1. Update type definitions here when adding new business entities
2. Update DATA_FLOW.yaml to reflect new data_packet types
3. Update ARCHITECTURE_RULES.md for any architectural pattern changes

---

## 📊 Core Business Entities

### 1. Session Model

**Purpose**: Represents a single block of tracked work/time. Must be Codable for CSV persistence.

**Key Features:**

- ✅ **Timestamp-Based**: Uses `startDate` and `endDate` (Date objects) as single source of truth
- ✅ **Migration Complete**: No longer uses computed properties - uses full Date objects
- ✅ **ProjectID Required**: New sessions require projectID parameter
- ✅ **Automatic Duration**: Duration calculated on-demand using `session.durationMinutes` computed property

#### SessionRecord Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `startDate` | Date | ✅ | Full timestamp: 2024-12-15 22:30:00 |
| `endDate` | Date | ✅ | Full timestamp: 2024-12-16 00:02:00 |
| `projectName` | String | ✅ | Kept for backward compatibility |
| `projectID` | String? | ⚠️ | Required for new sessions, optional for legacy |
| `activityTypeID` | String? | ❌ | Activity type identifier |
| `projectPhaseID` | String? | ❌ | Project phase identifier |
| `milestoneText` | String? | ❌ | Milestone text |
| `notes` | String | ✅ | Session notes |
| `mood` | Int? | ❌ | Mood rating (0-10) |

#### SessionRecord Initializers

**Legacy Session (backward compatibility):**

```swift
init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, notes: String, mood: Int?)
```

**Full Session (all fields):**

```swift
init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, projectID: String?, activityTypeID: String?, projectPhaseID: String?, milestoneText: String?, notes: String, mood: Int?)
```

**Modern Session (preferred for new sessions):**

```swift
init(id: String = UUID().uuidString, startDate: Date, endDate: Date, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, notes: String = "", mood: Int? = nil)
```

#### SessionRecord Methods

**`overlaps(with interval: DateInterval) -> Bool`**

- **Purpose**: Check if session overlaps with a date interval
- **Returns**: `true` if session overlaps with the given interval

---

### 2. Project Model

**Purpose**: Represents the entities being tracked. Must be Codable for JSON persistence.

#### Project Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Project name |
| `color` | String | ✅ | Project color (hex code) |
| `about` | String? | ❌ | Project description |
| `order` | Int | ✅ | Display order |
| `emoji` | String | ✅ | Project emoji |
| `archived` | Bool | ✅ | Archive status |
| `phases` | [Phase] | ✅ | Project phases |

#### Project Computed Properties

**`totalDurationHours: Double`**

- **Purpose**: Calculate total duration in hours for this project
- **Implementation**: Uses ProjectStatisticsCache for performance optimization
- **Fallback**: Calculates from SessionManager if cache miss

**`lastSessionDate: Date?`**

- **Purpose**: Get the date of the last session for this project
- **Implementation**: Uses ProjectStatisticsCache for performance optimization
- **Fallback**: Calculates from SessionManager if cache miss

**`swiftUIColor: Color`**

- **Purpose**: Convert hex color to SwiftUI Color
- **Implementation**: Uses JujuUtils.Color(hex:) extension

#### Project Initializers

**Full Project:**

```swift
init(id: String, name: String, color: String, about: String?, order: Int, emoji: String = "📁", phases: [Phase] = [])
```

**Basic Project:**

```swift
init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0, emoji: String = "📁", phases: [Phase] = [])
```

---

### 3. Phase Model

**Purpose**: Represents project subdivisions/milestones.

#### Phase Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Phase name |
| `order` | Int | ✅ | Display order |
| `archived` | Bool | ✅ | Archive status |

#### Phase Initializer

```swift
init(id: String = UUID().uuidString, name: String, order: Int = 0, archived: Bool = false)
```

---

### 4. ActivityType Model

**Purpose**: Represents the type of work being done (e.g., Coding, Writing).

#### ActivityType Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Activity type name |
| `emoji` | String | ✅ | Activity type emoji |
| `description` | String | ✅ | Activity type description |
| `archived` | Bool | ✅ | Archive status |

#### ActivityType Initializer

```swift
init(id: String, name: String, emoji: String, description: String = "", archived: Bool = false)
```

---

## 🔄 Supporting Data Types

### Session Data Transfer Object

**Purpose**: Transfer object for session data creation.

#### SessionData Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `startTime` | Date | ✅ | Session start time |
| `endTime` | Date | ✅ | Session end time |
| `durationMinutes` | Int | ✅ | Calculated duration |
| `projectName` | String | ✅ | Project name (backward compatibility) |
| `projectID` | String | ✅ | Project identifier (required for new sessions) |
| `activityTypeID` | String? | ❌ | Activity type identifier |
| `projectPhaseID` | String? | ❌ | Project phase identifier |
| `milestoneText` | String? | ❌ | Milestone text |
| `notes` | String | ✅ | Session notes |

#### SessionData Initializer

```swift
init(startTime: Date, endTime: Date, durationMinutes: Int, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, notes: String)
```

---

### Year-Based File System Models

#### YearlySessionFile Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `year` | Int | ✅ | Year (e.g., 2024) |
| `fileName` | String | ✅ | File name (e.g., "2024-data.csv") |
| `fileURL` | URL | ✅ | Full file path |

#### YearlySessionFile Initializer

```swift
init(year: Int, jujuPath: URL)
```

---

### Data Migration Models

#### DataMigrationResult Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `success` | Bool | ✅ | Migration success status |
| `migratedSessions` | Int | ✅ | Number of sessions migrated |
| `createdProjects` | [String] | ✅ | List of created project names |
| `errors` | [String] | ✅ | List of migration errors |

#### DataMigrationResult Initializer

```swift
init(success: Bool, migratedSessions: Int, createdProjects: [String] = [], errors: [String] = [])
```

---

### Data Validation Models

#### DataIntegrityReport Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `isValid` | Bool | ✅ | Overall validation status |
| `errors` | [String] | ✅ | List of validation errors |
| `warnings` | [String] | ✅ | List of validation warnings |
| `repairsPerformed` | [String] | ✅ | List of automatic repairs performed |

#### DataIntegrityReport Initializer

```swift
init(isValid: Bool, errors: [String] = [], warnings: [String] = [], repairsPerformed: [String] = [])
```

---

### Dashboard Data Models

#### DashboardData Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `weeklySessions` | [SessionRecord] | ✅ | Sessions for the current week |
| `projectTotals` | [String: Double] | ✅ | Project ID to total hours mapping |
| `activityTypeTotals` | [String: Double] | ✅ | Activity type ID to total hours mapping |
| `narrativeHeadline` | String | ✅ | Generated narrative headline |

#### DashboardData Initializer

```swift
init(weeklySessions: [SessionRecord], projectTotals: [String: Double], activityTypeTotals: [String: Double], narrativeHeadline: String)
```

---

### Filter Bar Data Models

#### DateRange Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `startDate` | Date | ✅ | Filter start date |
| `endDate` | Date | ✅ | Filter end date |

**Computed Properties:**

- `isValid: Bool` - Returns true if startDate <= endDate
- `durationDescription: String` - Human-readable duration (e.g., "7d")

#### DateRange Initializer

```swift
init(startDate: Date, endDate: Date)
```

#### SessionsDateFilter Enum

**Available Options:**

- `today` - "Today"
- `thisWeek` - "This Week"
- `thisMonth` - "This Month"
- `thisYear` - "This Year"
- `custom` - "Custom Range"
- `clear` - "Clear"

---

### Chart Data Models

#### ChartDataPoint Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `label` | String | ✅ | Data point label |
| `value` | Double | ✅ | Data point value |
| `color` | String | ✅ | Data point color (hex) |

#### BubbleChartDataPoint Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `x` | Double | ✅ | X-axis value |
| `y` | Double | ✅ | Y-axis value |
| `size` | Double | ✅ | Bubble size |
| `label` | String | ✅ | Bubble label |
| `color` | String | ✅ | Bubble color (hex) |

---

### Editorial Engine Data Models

#### PeriodSessionData Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `period` | ChartTimePeriod | ✅ | Time period (week/month/year) |
| `sessions` | [SessionRecord] | ✅ | Sessions in this period |
| `totalHours` | Double | ✅ | Total hours in this period |
| `topActivity` | (name: String, emoji: String) | ✅ | Top activity info |
| `topProject` | (name: String, emoji: String) | ✅ | Top project info |
| `milestones` | [Milestone] | ✅ | Milestones achieved |
| `averageDailyHours` | Double | ✅ | Average hours per day |
| `activityDistribution` | [String: Double] | ✅ | Activity ID to hours mapping |
| `projectDistribution` | [String: Double] | ✅ | Project name to hours mapping |
| `timeRange` | DateInterval | ✅ | Time range for this period |

#### ComparativeAnalytics Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `current` | PeriodSessionData | ✅ | Current period data |
| `previous` | PeriodSessionData | ✅ | Previous period data |
| `trends` | AnalyticsTrends | ✅ | Trend analysis results |

#### AnalyticsTrends Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `totalHoursChange` | Double | ✅ | Percentage change in total hours |
| `topActivityChange` | (from: String, to: String, change: Double) | ✅ | Top activity change |
| `topProjectChange` | (from: String, to: String, change: Double) | ✅ | Top project change |
| `milestoneCountChange` | Int | ✅ | Change in milestone count |
| `averageDailyHoursChange` | Double | ✅ | Change in average daily hours |
| `activityDistributionChanges` | [String: Double] | ✅ | Activity distribution changes |
| `projectDistributionChanges` | [String: Double] | ✅ | Project distribution changes |

#### ChartTimePeriod Enum

**Available Options:**

- `week` - "This Week"
- `month` - "This Month"
- `year` - "This Year"
- `allTime` - "All Time"

**Computed Properties:**

- `previousPeriod: ChartTimePeriod` - Previous period for comparison
- `durationInDays: Int` - Duration in days for normalization

---

### Dashboard View Type for Navigation

#### DashboardViewType Enum

**Available Options:**

- `weekly` - "Weekly"
- `yearly` - "Yearly"

**Computed Properties:**

- `title: String` - Display title
- `next: DashboardViewType` - Next view type in sequence

---

## 🎨 Color Support Extension

#### Color Extension

**Purpose**: Convert hex color strings to SwiftUI Color objects

**Initializer:**

```swift
init(hex: String)
```

**Parameters:**

- `hex: String` - Hex color string (e.g., "#FF5733")

**Implementation:**

- Supports both "#RRGGBB" and "RRGGBB" formats
- Parses hex values and converts to RGB components
- Creates SwiftUI Color with normalized RGB values (0.0-1.0)

---

## 📋 Summary

This architecture schema defines all core business entities for the Juju time-tracking application:

### **Core Entities (Primary Business Objects):**

1. **SessionRecord** - Individual time tracking sessions
2. **Project** - Trackable projects with phases
3. **Phase** - Project subdivisions/milestones
4. **ActivityType** - Types of work being done

### **Supporting Data Types:**

- **SessionData** - Session creation transfer object
- **YearlySessionFile** - File system organization
- **DataMigrationResult** - Migration tracking
- **DataIntegrityReport** - Validation results
- **DashboardData** - Dashboard display data

### **UI/UX Data Types:**

- **DateRange** - Date filtering
- **SessionsDateFilter** - Date filter options
- **FilterExportState** - Filter state management
- **ChartDataPoint** - Chart data points
- **BubbleChartDataPoint** - Bubble chart data points

### **Advanced Analytics:**

- **PeriodSessionData** - Time period analytics
- **ComparativeAnalytics** - Comparative analysis
- **AnalyticsTrends** - Trend analysis
- **ChartTimePeriod** - Time period definitions

### **Navigation:**

- **DashboardViewType** - Dashboard navigation

### **Utilities:**

- **Color Extension** - Hex color conversion

### **Helper Extensions:**

#### **Date+SessionExtensions**
**Purpose**: Session-specific date manipulation utilities for consistent date/time operations
**Key Methods**:
- `parseSessionDate(_:)` - Parse date strings in "yyyy-MM-dd" format
- `combined(withTimeString:)` - Combine dates with time strings
- `adjustedForMidnightIfNeeded(endTime:)` - Handle midnight sessions
- `formattedForSession()` - Format dates for storage
- `formattedForSessionDateTime()` - Format date/time for storage

#### **SessionRecord+Filtering**
**Purpose**: Session-specific filtering and validation utilities
**Key Methods**:
- `isInInterval(_:)` - Check if session falls within date interval
- `isForProject(_:)` - Filter sessions by project ID
- `hasActivityType(_:)` - Filter sessions by activity type
- `isInCurrentWeek/Month/Year` - Convenience properties for common date checks
- `overlaps(with:)` - Detect time conflicts between sessions
- `durationMinutes` - Safe duration calculation

#### **Array+SessionExtensions**
**Purpose**: Session array manipulation utilities
**Key Methods**:
- `filteredByProject(_:)` - Filter sessions by project ID
- `filteredByActivityType(_:)` - Filter sessions by activity type
- `filteredByDateInterval(_:)` - Filter sessions by date range
- `filteredByDateFilter(_:)` - Filter sessions by common time periods
- `sortedByStartDate()` - Sort sessions chronologically
- `groupedByDate()` - Group sessions by date for display
- `totalDurationMinutes()` - Calculate total duration
- `uniqueProjectIDs()` - Extract unique project IDs

#### **View+DashboardExtensions**
**Purpose**: Dashboard-specific view composition utilities
**Key Methods**:
- `dashboardPadding()` - Apply consistent dashboard padding
- `chartPadding()` - Apply consistent chart padding
- `loadingOverlay(isLoading:message:)` - Create loading overlays
- `chartContainer()` - Style chart components
- `dashboardCard()` - Style dashboard cards
- `dashboardContainer()` - Create responsive dashboard layouts
- `withHeader(title:subtitle:)` - Add standardized headers
- `section(title:)` - Create styled sections

All components in the application must use these exact type definitions to ensure consistency and maintainability.
