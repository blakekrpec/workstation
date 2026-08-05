# GNOME settings

Raw `dconf` dumps, applied by `roles/gnome`. Nothing here is hand-written.

## Capturing a tree

On the machine that already looks right:

```bash
dconf dump /org/gnome/shell/ > dotfiles/gnome/shell.ini
```

Commit it, then converge on the other machine. `roles/gnome` diffs the live
tree against the file and only calls `dconf load` when they differ, so a
converged machine reports `changed=0`.

Trees are listed in `roles/gnome/defaults/main.yml`. A tree named there with
no file yet is skipped, so you can add the path before you have the dump.

## Which trees

| File | Tree | Holds |
|---|---|---|
| `shell.ini` | `/org/gnome/shell/` | enabled extensions, favourites, per-extension config |
| `desktop.ini` | `/org/gnome/desktop/` | keybindings, interface, fonts, wallpaper |
| `settings-daemon.ini` | `/org/gnome/settings-daemon/` | media keys, power, custom shortcuts |
| `mutter.ini` | `/org/gnome/mutter/` | window management, workspaces |

## Two things to watch

**Dumps are not portable wholesale.** They can carry machine-specific values —
monitor layouts, absolute wallpaper paths, device IDs. Read the diff before
committing a dump from another machine rather than pasting it in blind.

**Extensions must exist before their settings mean anything.** `shell.ini`
carries `enabled-extensions`, but naming an extension there does not install
it. Packaged ones go in `gnome_extension_packages`; anything from
extensions.gnome.org gets installed once via the Extension Manager GUI, after
which its settings ride along in `shell.ini`.

Currently enabled on this machine: `ding`, `ubuntu-dock`, `tiling-assistant`.
