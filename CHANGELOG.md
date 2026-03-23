# Changelog - WHB Loot Tracker Classic

All notable changes to this project will be documented in this file.

## [1.7.3 French Toast] - 2026-03-21

**✨ New Features & Updates**
* **Item ID Database Lookup:** Completely rebuilt the "Manual Add" tab. Instead of fighting the modern WoW chat UI to intercept shift-clicks, the tool now strictly accepts numeric **Item IDs** (e.g., *28773*). It queries the local client cache to pull the official, flawless, color-coded item link directly from the server.
* **Live Guild Roster Tracking:** Added an "Online Addon Users" counter to the Credits tab. When opened, it runs a silent background ping/pong check across the guild channel to show exactly how many members are actively running the tracker.
* **Class Colors in Viewer:** Player names in the main loot viewer are now painted with their official Blizzard class colors. The addon silently caches the guild roster upon logging in to map class data to player names.
* **Ragefire Chasm Testing Ground:** Added Ragefire Chasm (RFC) to the valid tracking zones and explicitly bypassed the `IsInRaid()` lock for this specific dungeon to allow Officers to test the addon in a 5-man environment.

**🛠️ Quality of Life (QoL)**
* **Master Loot "No to All" Flow:** When the Master Looter loots an item to themselves, the item is safely stashed as "Pending Trade" to prevent database clutter, and a confirmation dialog pops up. Added a **"No to All"** button to this dialog that suppresses the popup for the remainder of the instance—perfect for vacuuming up trash loot.
* **Auto-Reassign Pending Trades:** The auto-trade tracking engine was updated so that when you trade an item to a winner, it actively hunts down and overwrites items labeled as "Pending Trade".
* **Cursor Snapping:** When manually adding an item, submitting the entry will automatically clear the fields and reset your focus, streamlining bulk entries.

**🐛 Bug Fixes**
* **Blank "Added By" Tags:** Fixed a formatting error where natural boss drops were evaluating an empty string as `true`, resulting in an ugly `(Added by )` tag in the viewer and CSV exports. Implemented strict `nil` checks to ensure standard loot drops stay clean.

---

## [1.7.0 🥚EggsBenny] - 2026-03-21

### 🚀 Added
- **Retroactive Session Targeting:** Officers can now attach manually added loot directly to an *existing* raid session. Selecting a previous run from the new "Target Session" dropdown automatically syncs the date, zone, and group tags to keep your database and exports perfectly organized.

---

## [1.7.0] - 2026-03-21

### 🚀 Added
- **Manual Add Engine:** Added a dedicated "Manual Add" tab to the main UI. Officers can now easily inject missed loot, log Guild Bank deposits, or correct historical data using a clean graphical interface (no slash commands required). You can even Shift-Click items directly into the text box!
- **Accountability & Transparency (Paper Trail):** Every manually added item now permanently records the name of the Officer who created the entry. This is broadcast to the guild, displayed in the viewer as `(Added by OfficerName)`, and included in the CSV Export to ensure complete transparency.
- **Strict Officer Lockdowns:** The "Manual Add" button is strictly locked behind Sync Permissions. Normal guild members will see the button permanently grayed out.

---
## [1.6.2] - 2026-03-21

### 🚀 Added

- **Doomdrizzle** Added to the credits

### 🐞 Fixed

- **API Compatibility Fix:** Resolved a critical crash (`attempt to call global 'GetLootMethod'`) caused by recent changes to the World of Warcraft internal API. Replaced with a version-safe global check.

---

## [1.6.1] - 2026-03-21

### 🐞 Fixed
- **Discord Popup Fix:** Resolved a critical Lua error (`attempt to index field 'editBox'`) where the Discord link popup failed to initialize on certain client locales.
- **Version Parity:** Updated all internal version strings to 1.6.1 to ensure the passive guild version checker functions correctly.

---

## [1.6.0] - 2026-03-21

### 🚀 Added
- **Credits & Community Page:** Added a dedicated Credits panel within the addon to recognize the core team and contributors.
- **Discord Integration:** Integrated a "Join our Discord" button on the Credits page that launches a popup for quick copying of the guild link: `https://discord.gg/whbguild`.
- **Intelligent Roster Monitor:** The addon now automatically scans the raid roster for guild members. If it detects a PUG or mixed run (9 or fewer guild members in a 10m, or 18 or fewer in a 25m), it will proactively prompt to confirm if loot should be tracked.
- **Proactive Tracking Prompt:** The confirmation logic now triggers the moment a raid leader swaps to **Master Looter** while inside a supported raid instance, allowing officers to set up before the first pull.

---

## [1.5.3] - 2026-03-21

### 🚀 Added
- **Auto-Trade Tracking Engine:** Master Looters rejoice! You can now vacuum up all boss loot and distribute it later while clearing trash. The addon silently monitors trade windows; when an Officer trades an item they looted to a raid member, the addon automatically reassigns ownership and broadcasts the fix to the guild. Zero clicks required!
- **Live Player Search:** Added a search bar to the main viewer. Type a player's name (or partial names like "Bank") to instantly filter the loot history in real-time.
- **Search-Aware Export:** The CSV Exporter now respects the player search box. Filtering the viewer down to a specific player will export *only* that player's loot data.
- **Quick Command Alias:** Added `/whb` as a fast, alternative slash command to open the loot viewer alongside `/whbloot`.

### 🔒 Security & Quality of Life
- **Strict Officer Verification:** The sync engine now performs a background roster check on all incoming `MOD`, `DEL`, and `PERM` commands. The database will automatically reject and ignore spoofed commands sent by non-officers, making your data bulletproof.
- **Data Wipe Protection:** Added a confirmation popup to the "Clear All Data" button to completely eliminate the risk of accidental database wipes.
- **Test Command Lockout:** The `/whbtest` command is now strictly locked. Only Officers with Sync Access can inject test data, preventing normal guild members from accidentally polluting their local databases with fake legendaries.

---

## [1.5.1] - 2026-03-21

### 🚀 Added
- **Live Player Search:** Added a search bar to the main viewer. You can now type a player's name (or partial names like "Bank" or "Disenchant") to instantly filter the loot history in real-time.
- **Search-Aware Export:** The CSV Exporter has been upgraded to respect the new player search box. Filtering the viewer down to a specific player will now only export that specific player's loot data.
- **Quick Command Alias:** Added `/whb` as a fast, alternative slash command to open the loot viewer alongside the standard `/whbloot`.

### 🔒 Security & Permissions
- **Test Command Lockout:** The `/whbtest` command is now strictly locked. Only Officers with Sync Access can inject test data, preventing normal guild members from accidentally polluting their local databases with fake legendaries.

---

## [1.5.0] - 2026-03-21

### 🚀 Added
- **10-Man Group Tracking:** Added support for multiple progression rosters. Loot dropped in 10-man raids (Karazhan, Zul'Aman) can now be tagged to a specific group (Group 1 through 5). All 25-man raid loot safely defaults to the "Main Raid" tag.
- **Triple-Dropdown Filtering:** Upgraded the viewer UI to support 3-way sorting. You can now filter your loot history by Zone, then by Group, and finally by Date. 
- **Passive Version Checker:** The addon now silently checks versions with other guild members upon logging in. If your version is out of date, it will print a helpful red warning in chat directing you to download the latest version from CurseForge.
- **Group CSV Export:** The CSV Exporter has been updated to include a dedicated "Group" column to keep your spreadsheets perfectly organized.

### 🔒 Security & Permissions
- **Complete Options Lockout:** The entire internal Options panel (Minimum Quality, Ignore List, Active 10-Man Group, and the Death Announcer) is now strictly locked and visually grayed out for normal guild members. Only Officers with Sync Access can change how the addon tracks loot.

---

## [1.4.0] - 2026-03-21

### 🚀 Added
- **Loot Reassignment Engine:** Officers with sync permissions can now modify who received a piece of loot after it has already been recorded. Right-click the gold timestamp to access the new modification menu.
- **Custom Player Assignment:** Added an "Assign to Player..." option. This opens a clean, focused text box where you can manually type in the correct player's name to fix misclicks.
- **Bank & Disenchant Tracking:** Added quick-action buttons to the right-click menu to instantly reassign an item's recipient to "Bank" or "Disenchant".
- **Real-Time Modification Syncing:** Built a new `MOD~` protocol into the guild sync system. Whenever an officer reassigns an item, sends it to the bank, or marks it for disenchantment, the change is instantly beamed to everyone else's database in the guild without needing to push a full sync.

---

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