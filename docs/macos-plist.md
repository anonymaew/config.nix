# macOS System Settings → nix-plist-manager (migration record)

**Status:** ✅ Applied — switched 2026-09-29 23:33, relogged in 2026-09-30; staged, not committed
**Host:** macair (aarch64-darwin, macOS 27 / build 26A428)
**Upstream:** [`SushyDev/nix-plist-manager`](https://github.com/SushyDev/nix-plist-manager) pinned to **v3.0.0** (`f3ac4aa`, 2026-09-24, MIT)
**Scope:** user settings only; system scope (firewall, sharing, power, login window) not adopted yet

## Why

`system.defaults` in `hosts/macair/default.nix` covered ~15 macOS preferences by
hand and had no vocabulary for the rest of System Settings. nix-plist-manager
declares 506 per-user settings with names and values copied from the UI
(`"Sunset to Sunrise"`, `"Three Finger Drag"`, …), applies them the way macOS
does (Dock restart, `notifyutil`, `activateSettings -u`), and ships a
`current`/`capture` pair to read the Mac's live state back as Nix.

macOS 27 / 26A428 is exactly the build upstream verifies against, so no
compatibility risk.

Key architectural point: the plugin exports **two** modules. `darwinModules.default`
manages the machine as root (system scope), `homeManagerModules.default` manages
the user (user scope). This migration adopts only the latter, so
`programs.nix-plist-manager.options` is a home-manager option and cannot be set
from the darwin host module.

## Shape

```text
flake.nix                        input: nix-plist-manager (v3.0.0, nixpkgs follows)
modules/darwin.nix               imports homeManagerModules.default + hosts/macair/mac.nix
hosts/macair/mac.nix             the declared settings (user scope) + snapshot paths
hosts/macair/snapshots/contents  dock apps (persistent-apps / persistent-others)
hosts/macair/snapshots/layout    menu bar (trackedApplications, positions, siri, spotlight)
hosts/macair/snapshots/wallpaper wallpaper index (all Spaces + displays)
hosts/macair/default.nix         system.defaults removed; stateVersion + system.keyboard kept
```

`mac.nix` is imported into the home-manager user, not the darwin host, because
the user-scope option tree only exists inside home-manager.

## Migration map

| Was (`system.defaults`) | Now (`programs.nix-plist-manager.options…`) |
| --- | --- |
| `dock.autohide = true` | `desktopAndDock.dock.automaticallyHideAndShowTheDock.enabled` |
| `dock.show-recents = false` | `desktopAndDock.dock.showSuggestedAndRecentAppsInDock` |
| `dock.tilesize = 48` | `desktopAndDock.dock.size = 48` |
| `dock.persistent-apps = [ ]` | `desktopAndDock.dock.contents` (snapshot) |
| `dock.wvous-bl-corner = 13` | `desktopAndDock.hotCorners.bottomLeft.action = "Lock Screen"` |
| `NSGlobalDomain.AppleInterfaceStyle = "Dark"` | `appearance.appearance = "Dark"` |
| `NSGlobalDomain.AppleICUForce24HourTime = true` | `general.dateAndTime."24HourTime" = true` |
| `NSGlobalDomain.AppleMetricUnits` / `AppleMeasurementUnits` | `general.languageAndRegion.measurementSystem = "Metric"` |
| `NSGlobalDomain.KeyRepeat = 2` | `keyboard.keyRepeatRate = 2` |
| `NSGlobalDomain.InitialKeyRepeat = 15` | `keyboard.delayUntilRepeat = 15` |
| `NSGlobalDomain."com.apple.trackpad.scaling" = 3.0` | `trackpad.pointAndClick.trackingSpeed = 3.0` |
| `controlcenter.BatteryShowPercentage = true` | `menuBar.batteryOptions.showPercentage` |
| `hitoolbox.AppleFnUsageType` | `keyboard.pressGlobeKeyTo = "Show Emoji & Symbols"` |
| `CustomUserPreferences.NSGlobalDomain.AppleMenuBarVisibleInFullscreen=false` + `com.apple.controlcenter.AutoHideMenuBarOption=2` | `menuBar.autoHideAndShowTheMenuBar = "In Full Screen Only"` |
| `menuExtraClock.ShowSeconds = true` | `menuBar.clock.displayTheTimeWithSeconds = true` (+ `clock.style = "Digital"`) |

`menuBar.clock.style = "Digital"` was added during migration: the seconds switch
warns when the clock style is unmanaged, and the Mac is on the digital clock.

### Not covered — stays in nix-darwin

| Setting | Reason |
| --- | --- |
| `system.keyboard.remapCapsLockToEscape` | No caps-lock/modifier-remap option upstream |
| `system.keyboard.enableKeyMapping` | Same; it drives the mapping activation |
| `system.stateVersion` | nix-darwin bookkeeping |

Observed while migrating (pre-existing, not caused by this change):
`defaults read -g com.apple.keyboard.modifiermapping.0-0-0` is empty, so the
caps-lock→escape remap declared in `system.keyboard` does not appear to be in
effect on macOS 27. Worth a separate look.

## Snapshots

Three settings are arranged rather than typed and are stored as committed plists:

- `desktopAndDock.dock.contents` → `snapshots/contents/{apps,others}.plist`
- `menuBar.layout` → `snapshots/layout/{applications,positions,showSiri,showSpotlight}.plist`
- `wallpaper.wallpaper` → `snapshots/wallpaper/index.plist`

Re-capture after rearranging:

```sh
nix run github:sushydev/nix-plist-manager#capture -- \
  applications.systemSettings.desktopAndDock.dock.contents hosts/macair/snapshots/contents
nix run github:sushydev/nix-plist-manager#capture -- \
  applications.systemSettings.menuBar.layout hosts/macair/snapshots/layout
nix run github:sushydev/nix-plist-manager#capture -- \
  applications.systemSettings.wallpaper.wallpaper hosts/macair/snapshots/wallpaper
```

Dock contents are restored with a state-discarding Dock restart, so the Dock
cannot overwrite what was just imported when it quits.

## Capture provenance and curation

The file was produced with:

```sh
nix run github:sushydev/nix-plist-manager#current -- \
  hosts/macair/mac.nix --scope user --snapshots hosts/macair/snapshots
```

(116 settings read; 46 at macOS default and therefore omitted; 53 with no known
default included and then reviewed by hand.)

Kept beyond the `system.defaults` migration: Finder sidebar/desktop items,
AirDrop `Everyone`, `en-US`/`th-US` + region `en_US`, both input sources
(US + Manoonchai Colemak DH Ukelele layout), Mission Control shortcuts disabled,
bottom-right "Quick Note" hot corner, notification summaries off, personalized
ads off, Spotlight result choices, trackpad rotate/zoom.

Dropped as noise (re-add from the capture if wanted): all Accessibility entries
(sticky/slow keys, hover text, live captions, zoom shortcuts, background sound /
voices / shortcuts snapshots), `appearance.liquidGlass`, Siri `enable = false`,
`sharing.mediaSharing`, `textInput` capitalization switches, default input-source
shortcuts, `menuBar.clock.showAmPm`, empty top hot corners, and the per-app
notifications snapshot.

Known oddity left unmanaged: `com.apple.menuextra.clock` holds both
`Show24Hour=1` and `ShowAMPM=1`. As before this migration, `showAmPm` is not
declared, so nothing pins the stale AM/PM bit; 24-hour time comes from
`AppleICUForce24HourTime`.

## Applying and keeping in sync

```sh
git add -A
sudo darwin-rebuild switch --flake .
# log out / in: key repeat, input sources, menu bar layout only after a new session
```

After changing something in System Settings, print just the difference:

```sh
nix run github:sushydev/nix-plist-manager#current -- \
  --scope user --against hosts/macair/mac.nix
```

The tool writes plists with `/usr/bin/defaults` in an activation script
(`home.activation."nix-plist-manager"`, after `writeBoundary`). A refused step
prints `nix-plist-manager: failed: …` on stderr and does not abort the rest of
the activation. Module warnings (e.g. two settings that conflict) surface at
build time; silence intentional ones via
`programs.nix-plist-manager.ignoreWarnings`.

## Rollback

1. Revert `hosts/macair/default.nix` to restore the old `system.defaults` block.
2. Remove the two imports added in `modules/darwin.nix` and the
   `nix-plist-manager` input from `flake.nix` (`nix flake update`).
3. Delete `hosts/macair/mac.nix` and `hosts/macair/snapshots/`.
4. `sudo darwin-rebuild switch --flake .`.

Values previously written by nix-plist-manager stay in the plists until the
restored `system.defaults` (or a manual `defaults delete`) overwrites them.
