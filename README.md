# WHB Loot Tracker Classic
![Addon Icon](logo.png)

**Version:** 1.5.3  
**Author:** Maliettv-Nightslayer US | Waffle House Brawlers  
**Compatibility:** WoW Classic Era, Season of Discovery, TBC Anniversary, WotLK Classic, Cataclysm Classic

## Overview
Built originally for the **Waffle House Brawlers**, this addon is a lightweight, highly secure raid loot tracker that takes the headache out of managing guild spreadsheets. It quietly runs in the background during your raids, records who got what (and where), and allows you to instantly export the data to Excel or Google Sheets.

Whether you are progressing through 25-man content or running multiple 10-man roster splits, the WHB Loot Tracker keeps your guild's loot history perfectly synced, strictly moderated, and easily manageable.

## ✨ Key Features

### Core Tracking & UI
* **In-Game Loot Viewer:** A fully resizable, clean interface that logs all loot drops. Hover over item links right in the viewer to see their stats.
* **Advanced Filtering & Player Search:** Filter your history effortlessly using triple-dropdowns (**Zone -> Group -> Date**). Use the **Live Search Bar** to instantly filter the database by player name or keyword (e.g., type "Bank").
* **10-Man Roster Support:** The addon automatically detects if you are in a 10-man raid (like Karazhan or Zul'Aman) and tags the loot to your active progression roster (Group 1 through 5) so it doesn't pollute your 25-man "Main Raid" database. 
* **Smart CSV Export:** Click "Export CSV" to generate a pre-formatted block including Date, Player, Item, Zone, and Group. The export respects your active filters and search bar—filter down to a specific player and export *only* their data.

### ⚔️ Master Looter & Officer Tools
* **Auto-Trade Tracking:** Master Looters can vacuum up all boss drops to keep the raid moving and distribute the items later while clearing trash. The addon silently watches your trade window—when an Officer trades a tracked item to a raid member, the addon automatically reassigns ownership and broadcasts the fix to the guild. Zero clicks required!
* **Right-Click Modifications:** Authorized officers can **Right-Click** the gold timestamp on any entry to manually Assign to a Player, send to Bank, mark as Disenchanted, or Delete the line completely.
* **Targeted Data Recovery:** Did a guild member miss raid night or wipe their data? They can click the "Request Data" button to silently ask online Officers for an update. The addon will securely "Whisper-Sync" the missing database directly to them.

### 🔄 Intelligent Guild Syncing & Security
* **Passive Sync:** Whenever a piece of loot drops or gets reassigned, the addon silently whispers that data to other guild members using the tracker, ensuring everyone stays up to date in real-time.
* **Granular Permissions:** The Guild Master can open the Options tab to grant specific guild ranks permission to modify the database. 
* **Bulletproof Verification:** The sync engine performs a background roster check on all incoming commands. It automatically rejects spoofed database changes sent by non-officers.
* **Passive Version Checker:** Guild members running an outdated version of the addon will get a polite reminder in their chat box to update via CurseForge when they log in.

### 💀 The Death Announcer (Easter Egg)
Tucked away in the Options menu is a customizable Death Announcer. Type in the name of your guild's most notoriously clumsy player and check the box. The addon will automatically announce *"[PlayerName] is dead again."* to guild chat whenever they meet an untimely demise. 

## ⌨️ Slash Commands

* `/whb` or `/whbloot` — Opens the main Loot Viewer.
* `/whbtest` — *(Officer Only)* Injects a fake legendary test drop into your database. Allows you to test the viewer and CSV exporter without waiting for a raid.

## 🛠️ Installation

1. Download the latest release from [CurseForge](https://www.curseforge.com/wow/addons/whb-loot-tracker-classic) or the Releases tab on GitHub.
2. Extract the `.zip` file.
3. Place the `WHBLootTrackerClassic` folder into your World of Warcraft `_classic_/Interface/AddOns/` directory.
4. Launch the game and ensure the addon is enabled on your character select screen.