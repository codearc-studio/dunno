# Dunno 2.0 activities + widget/live activity polish patch

Replace these full files:
- dunno/Resources/Activities.json
- dunnoWidgets/DunnoSuggestionWidget.swift
- dunnoWidgets/DunnoLiveActivity.swift

What this pass does:
1. Replaces the activity catalog with the new validated 2,020-activity catalog.
   - catalogVersion: 5
   - 202 activities in each of the 10 categories
2. Removes the problematic Dunno icon usage from widgets / Live Activity and uses the text wordmark style instead.
3. Uses a light/white Dunno wordmark presentation on the dark Live Activity surfaces.
4. Fixes the elapsed label / timer alignment by making the clock block consistently trailing-aligned.
5. Simplifies widget spacing so titles, durations, and controls have more room and are less likely to clip.

Important after applying:
- Build and run the app.
- Remove and re-add widgets once.
- End any current Live Activity and start a fresh Doing Now session.

Notes:
- The accessory inline widget remains removed.
- This patch intentionally does not touch your Xcode project file so it is safer to apply on top of your current local project state.
