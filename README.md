# FAM - Flatpak Alias Manager

![Version](https://img.shields.io/badge/version-1.0-blue) ![License](https://img.shields.io/badge/license-GPLv3-green) ![Shell](https://img.shields.io/badge/shell-Bash%20%7C%20Zsh%20%7C%20Fish-orange)

**FAM** is a robust automation tool that bridges the gap between Flatpak applications and your terminal. It automatically generates native shell aliases for all your installed Flatpaks, making them accessible via their simple names (e.g., typing `gimp` instead of `flatpak run org.gimp.GIMP`).

It runs silently in the background, cleaning up your system and keeping your shell synchronized instantly, whether you install apps via the Terminal, GNOME Software, or KDE Discover.

## Features

* A 100% sudo-less script. Everything is done in the user space.
* Automatically maps the flatpak package `org.example.App` to `app` via a persistent alias.
* Checks the generated aliases for conflicts with native apps and renames them accordingly to prevent system breakage.
* Automatically removes orphaned runtimes to save disk space.
* Uses a Systemd Path Unit to watch for changes. As soon as you install a flatpak app by any means, FAM updates your aliases instantly.
* Native integration for **Bash**, **Zsh**, and **Fish**.
* Receive a subtle notification bubble when aliases are updated in the background.
* Run `fam` manually in the terminal to see a detailed status report.

## Installation

### 1. Download the Installer
Download the `fam-installer.sh` script by cloning this repository:

```bash
git clone [https://github.com/YOUR_USERNAME/fam.git](https://github.com/YOUR_USERNAME/fam.git)
cd fam
```

### 2. Make the script executable
`chmod +x fam-installer.sh`

### 2. Run the Installer

Run the installer script:
```Bash
./fam-installer.sh
```
Select Option [1] to install.

### 3. Restart Terminal

Close and reopen your terminal to load the new aliases.

## Usage
Once installed, you don't need to do anything else. To see it in acton, try:

- Installing an app: flatpak install flathub org.videolan.VLC
- Then, run it by just typing `vlc` on your terminal.

This also applies when installing an app via a GUI (such as GNOME Software or KDE's Discover). If successful, a notification will pop up telling you the alias is ready.

### Manual Mode
You can run the `fam` command manually at any time to force a sync or check its status. You'll get the following output adjusted to your settings:

```
------------------------------------------------------------
   FAM - FLATPAK ALIAS MANAGER v1.0
------------------------------------------------------------
 [+] Aliases synchronized
 [+] Unused runtimes cleaned
 [i] Total Aliases:  42
------------------------------------------------------------
```

## How it Works

- A Systemd user unit watches `/var/lib/flatpak` and `~/.local/share/flatpak`.
- When a change is detected, `fam` generates a list of aliases.
- A lightweight shell function intercepts flatpak operational commands to provide immediate response and provide visual feedback to the user.


## Uninstallation

If you wish to remove FAM, simply run the installer script again. It detects the installation and offers a clean removal option. This will:

- Stop and remove Systemd units.
- Remove the fam binary.
- Delete generated alias files.
- Removes related code blocks from your .bashrc, .zshrc, or .config/fish.

## License

This project is licensed under the **GNU General Public License v3.0**.

## Credits

- Original Concept & Logic: Vuk Hidalgo 
- Visual enhancements & AI Assistance: Google Gemini
