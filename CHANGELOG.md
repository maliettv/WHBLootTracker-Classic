# Changelog - WHB Loot Tracker Classic

All notable changes to this project will be documented in this file.


# Changelog - WHB Loot Tracker Classic

## [1.3.0] - 2026-03-20

### 🚀 Added
- **Instance-Aware Tracking:** The database now records the specific Raid/Zone where loot dropped. 
- **Dual Dropdown Filtering:** Overhauled the viewer UI. You can now filter by "Zone" and the "Date" dropdown will dynamically update to only show dates for that specific raid.
- **Line Item Deletion:** Authorized Officers can now Right-Click the gold timestamp on any loot entry to delete it. Deletions are instantly broadcasted to the entire guild to remove mistakes from everyone's database.
- **Customizable Death Announcer:** Replaced the hardcoded Easter Egg name. You can now type in the name of *any* guild member you want the addon to announce deaths for.
- **Helpful Tooltips:** Disabled buttons now feature hover tooltips explaining exactly why you can't click them (e.g., "Guild Master Only" or "Not in a Guild").
- **Extended CSV Export:** The CSV Exporter now includes a dedicated "Zone" column to match your guild spreadsheets.

### ⚙️ Changed
- **Granular Permissions Checklist:** Replaced the "minimum rank" dropdown with a checklist of every guild rank. The Guild Master can now hand-pick exactly which ranks are allowed to push DB Syncs.
- **Permission Broadcasting:** When an Officer pushes a sync, the addon now silently syncs the guild's permission settings to everyone else first.
- **Enhanced Sync Handshake:** Senders now get a clean summary in chat of exactly who received their data. Receivers get a notification telling them *who* is sending them a sync.
- **UI Repositioning:** Moved the "Clear All Data" button to the Options tab to prevent accidental wipes on the main viewer.
- **Test Command Upgrade:** `/whbtest` now awards the legendary test item to the player executing the command instead of a hardcoded name.

### 🔒 Security & Permissions
- **Visual Lockouts:** The "Push Full DB Sync" button visually grays out and disables if you do not have permission.
- **GM Exclusivity:** The "Clear All Data" button and the Permission Checkboxes are strictly locked and grayed out for everyone except the Guild Master (Rank 0).
- **Unguilded Protection:** The addon now safely detects if a character is not in a guild, hides guild-only features, and prevents Lua errors from popping up.

### 🛠 Fixed
- Fixed an issue where the viewer window would appear blank due to 0-pixel height frames.
- Fixed an overlap issue with the Zone and Date dropdown menus in the main viewer.
- Fixed a Lua error (`SetMinResize a nil value`) affecting users on newer game clients like TBC Anniversary and Cataclysm Classic.
- Added 20px of breathing room to the Raid Filter options panel for a cleaner look.

---

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