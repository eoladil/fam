# FAM - Flatpak Alias Manager

FAM is an automation tool that generates and manages shell aliases for Flatpak applications.  When active, it listens for new Flatpak installs or removals, updating the alias shell script accordingly.

For example, running `librewolf` on the terminal becomes the equivalent of running `flatpak run io.gitlab.librewolf-community`. If the command already exists, a `-flatpak` tag is added to the alias.

## Features

* Bash, Zsh, and Fish support.
* Automated detection of Flatpak changes via a `systemd` user service.
* Support for name overrides, blacklisting, and environment variable injection.
* Built-in configuration for backups and restores.

## Installation

* Download the `fam` script.
* Make it executable with `chmod +x fam`
* Launch it with `./fam`
* Select Option [1] to install.

## Usage
Run `fam` to sync aliases. Use flags below alone for **interactive menus** or with arguments for **manual configuration**.

| Category | Short | Long | Description | Manual Example |
| --- | --- | --- | --- | --- |
| **Core** | `-s` | `--show` | List active aliases and tags. | `fam -s` |
|  | `-f` | `--force` | Force alias regeneration. | `fam -f` |
|  | `-p` | `--preview` | Dry run (no files modified). | `fam -p` |
| **Config** | `-o` | `--override` | Set a custom alias name. | `fam -o [ID] [NAME]` |
|  | `-co` | `--clear-override` | Remove a custom alias. | `fam -co [ID]` |
|  | `-i` | `--ignore` | Blacklist an application. | `fam -i [ID]` |
|  | `-ui` | `--unignore` | Remove from blacklist. | `fam -ui [ID]` |
|  | `-e` | `--env` | Inject environment variables. | `fam -e [ID] [VARS]` |
| **Maint.** |  | `--backup` | Export config to tarball. | `fam --backup [PATH]` |
|  |  | `--restore` | Import config from tarball. | `fam --restore [PATH]` |
|  | `-r` | `--reinstall` | Repair systemd/shell hooks. | `fam -r` |
|  | `-u` | `--uninstall` | Completely remove FAM. | `fam -u` |

## Usage examples

* **Override:** `fam -o org.gimp.GIMP photoshop`
* **Ignore:** `fam -i org.vim.Vim` (Prevents shadowing native Vim)
* **Environment:** `fam -e org.mozilla.firefox MOZ_ENABLE_WAYLAND=1`
* **Backup:** `fam --backup ~/fam-config.tar.gz`

## Disclosure
Just a heads-up: this script was put together with some help from AI for learning purposes. It’s working great on Fedora Silverblue 44 right now, but I'll likely be doing some manual refactoring soon to clean things up.
