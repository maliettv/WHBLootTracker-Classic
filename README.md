# WHB Loot Tracker Classic
![Addon Icon](logo.png)

**WHB Loot Tracker Classic** is a lightweight, high-performance World of Warcraft addon designed specifically for the **Waffle House Brawlers** guild. It automates raid loot recording, provides real-time database syncing between members, and offers a seamless export path to spreadsheets like Excel or Google Sheets.

---

## 🚀 Key Features

### 📊 In-Game Loot Viewer
* **Dynamic UI:** Access your loot history instantly with `/whbloot`.
* **Interactive Tooltips:** Hover over item links within the viewer to see stats and item levels.
* **Fully Resizable:** Drag the bottom-right corner to scale the window to your interface needs.
* **Date Filtering:** A built-in dropdown menu allows you to filter by specific raid dates or view your entire history.

### 📥 One-Click CSV Export
* **Spreadsheet Ready:** Instantly generate CSV-formatted text.
* **Seamless Workflow:** Click **Export CSV**, press **Ctrl+C**, and paste directly into Excel or Google Sheets.

### ⚙️ Advanced Options
* **Raid Filtering:** Toggle tracking for specific TBC raids (Karazhan, Black Temple, Sunwell, etc.) via dedicated checkboxes.
* **Quality Thresholds:** Set minimum item quality (Uncommon, Rare, or Epic) to keep your database clean.
* **Custom Death Announcer:** A customizable feature that announces to guild chat when a specific player dies.

### 🔄 Intelligent Guild Syncing
* **Passive Sync:** New drops are automatically whispered to all guild members using the addon in real-time.
* **Officer Push:** Authorized ranks can broadcast the entire loot history to the guild.
* **Handshake Protocol:** The sender receives a confirmation list of which guild members successfully received the data.
* **Receiver Confirmation:** Members are notified in chat when they start and finish receiving a sync.

---

## 🛠 Commands

| Command | Action |
| :--- | :--- |
| `/whbloot` | Opens the main Viewer, Exporter, and Options interface. |
| `/whbtest` | Injects a legendary test entry (May 24, 2004) to verify filters and syncing. |

---

## 📂 Installation

1.  Download the repository as a **.zip** file.
2.  Extract the **WHBLootTrackerClassic** folder.
3.  Place the folder into your WoW AddOns directory:
    * **TBC Anniversary:** `_anniversary_\Interface\AddOns\`
    * **Classic Era / SoD:** `_classic_era_\Interface\AddOns\`
    * **Cataclysm Classic:** `_classic_\Interface\AddOns\`
4.  Restart World of Warcraft or type `/reload` in-game.

---

## 🔒 Permissions & Security

* **Rank Restriction:** Full database syncing is restricted to the **Guild Master** or a user-defined **Officer Rank** to prevent server spam.
* **Duplicate Protection:** The addon cross-references timestamps and item links to ensure no piece of loot is recorded twice.

---

## 📜 Credits

* **Author:** Maliettv-Nightslayer US
* **Guild:** Waffle House Brawlers
* **Copyright:** © 2026 Maliettv-Nightslayer US - Waffle House Brawlers

Made with ❤️ for Fartjars and Waffle House Brawlers Community.

No Realpowers died during the development of this Addon. 
