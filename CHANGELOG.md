# Changelog - WHB Loot Tracker Classic

All notable changes to this project will be documented in this file.

## [1.1 Alpha] - 2026-03-20
### Added
- **Core Engine:** Initial release of the Waffle House Brawlers Loot Tracker.
- **Dynamic UI:** Added a fully resizable and draggable main window for loot viewing.
- **Smart Filtering:** Added a date-based dropdown to filter loot by specific raid nights.
- **CSV Exporter:** Added a dedicated export mode to copy data directly into Excel/Google Sheets.
- **Guild Syncing:** - Passive real-time syncing for new drops.
  - Active "Push Sync" for Officers and Guild Masters.
  - Handshake protocol to confirm successful syncs across the guild.
- **Raid Settings:** Checkbox-based options to ignore specific TBC raids (Karazhan, BT, Sunwell, etc.).
- **Quality Thresholds:** User-defined minimum item quality for recording (Uncommon/Rare/Epic).
- **Death Announcer:** Customizable "Easter Egg" to announce specific player deaths to guild chat.
- **Permissions:** Added a Guild Rank dropdown to restrict full sync commands to authorized members.
- **Branding:** Official W.H.B. "Spatula & Sword" icon integration.

### Fixed
- **UI Scaling:** Fixed a bug where text was invisible on initial load due to 0-pixel height frames.
- **Client Compatibility:** Fixed Interface Options crashes by implementing a modern Settings API check for TBC Anniversary.
- **Cross-Version Support:** Added TOC tags for all Classic WoW clients (Era, SoD, TBC, Wrath, Cata).

---
*© 2026 Maliettv-Nightslayer US - Waffle House Brawlers*