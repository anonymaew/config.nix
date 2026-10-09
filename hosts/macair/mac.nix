# macOS System Settings, declared — user scope (home-manager).
#
# Captured from this Mac with:
#
#   nix run github:sushydev/nix-plist-manager#current -- \
#     hosts/macair/mac.nix --scope user --snapshots hosts/macair/snapshots
#
# then trimmed by hand: settings still at macOS's default, and ones we have no
# opinion about, were removed. Re-capture with `--against hosts/macair/mac.nix`
# after changing something in System Settings to see just what differs.
#
# Where each setting lives:
#   - What used to be `system.defaults` in hosts/macair/default.nix (dock,
#     dark mode, 24-hour time, key repeat, trackpad speed, menu bar, Fn key,
#     metric units, battery percentage, bottom-left hot corner) now lives here,
#     so nix-plist-manager is the single writer for those plists.
#   - `system.keyboard.remapCapsLockToEscape` / `enableKeyMapping` are NOT
#     covered by nix-plist-manager and stay in nix-darwin.
#   - System-wide settings (firewall, sharing, power, login window) are out of
#     scope for now; they belong to the nix-darwin module, not this file.
#
# Snapshots (hosts/macair/snapshots/*) are re-captured by hand when arranged:
#   desktopAndDock.dock.contents, menuBar.layout, wallpaper.wallpaper
#
# mac.nix is a home-manager module: it must be imported into the user, not into
# the darwin host (see modules/darwin.nix).
{
  programs.nix-plist-manager = {
    enable = true;

    options.applications = {
      finder = {
        menuBar.view.showSidebar = true;
        settings.general.showTheseItemsOnTheDesktop = {
          cdsDvdsAndiPods = true;
          externalDisks = true;
          hardDisks = false;
        };
      };

      systemSettings = {
        appearance.appearance = "Dark";

        desktopAndDock = {
          dock = {
            automaticallyHideAndShowTheDock.enabled = true;
            showSuggestedAndRecentAppsInDock = false;
            size = 48;
            contents = ./snapshots/contents;
          };
          hotCorners = {
            # was system.defaults.dock.wvous-bl-corner = 13
            bottomLeft.action = "Lock Screen";
            bottomRight.action = "Quick Note";
          };
          missionControl.shortcuts = {
            # Re-enabled natively now that skhd/aerospace are gone.
            applicationWindows = "⌥↓";
            missionControl = "⌥↑";
            showDesktop = "-";
          };
        };

        general = {
          airDropAndContinuity.airDrop = "Everyone";
          dateAndTime."24HourTime" = true; # was NSGlobalDomain.AppleICUForce24HourTime
          languageAndRegion = {
            measurementSystem = "Metric"; # was AppleMetricUnits / AppleMeasurementUnits
            preferredLanguages = [
              "en-US"
              "th-US"
            ];
            region = "en_US";
          };
        };

        keyboard = {
          delayUntilRepeat = 15; # was NSGlobalDomain.InitialKeyRepeat
          keyRepeatRate = 2; # was NSGlobalDomain.KeyRepeat
          pressGlobeKeyTo = "Show Emoji & Symbols"; # was hitoolbox.AppleFnUsageType
          textInput.inputSources = [
            "com.apple.keylayout.US"
            # Manoonchai Colemak DH (installed via Ukelele)
            "org.sil.ukelele.keyboardlayout.com.manoonchai.colemakdhm.manoonchai"
          ];

          # Native replacements for the removed aerospace/skhd bindings.
          # macOS Space switching + fixed-grid tiling (Sequoia+).
          keyboardShortcuts = {
            missionControl = {
              # was `alt-1..5 = workspace N`
              switchToDesktop1 = "⌥1";
              switchToDesktop2 = "⌥2";
              switchToDesktop3 = "⌥3";
              switchToDesktop4 = "⌥4";
              switchToDesktop5 = "⌥5";
              # was `alt-tab = workspace-back-and-forth`
              moveLeftASpace = "⌥←";
              moveRightASpace = "⌥→";
            };
            windows = {
              # fixed-grid tiling (was yabai/aerospace move + resize)
              tileLeftHalf = "⌥⌘←";
              tileRightHalf = "⌥⌘→";
              tileTopHalf = "⌥⌘↑";
              tileBottomHalf = "⌥⌘↓";
              fill = "⌥⌘F";
              minimize = "⌥⌘M";
            };
          };
        };

        menuBar = {
          # was AppleMenuBarVisibleInFullscreen + AutoHideMenuBarOption = 2
          autoHideAndShowTheMenuBar = "In Full Screen Only";
          batteryOptions.showPercentage = true; # was controlcenter.BatteryShowPercentage
          clock = {
            style = "Digital"; # displayTheTimeWithSeconds requires a digital clock
            displayTheTimeWithSeconds = true; # was menuExtraClock.ShowSeconds
            showTheDayOfTheWeek = true;
          };
          layout = ./snapshots/layout;
        };

        notifications.notificationCenter.summarizeNotifications = false;
        privacyAndSecurity.appleAdvertising.personalizedAds = false;

        spotlight = {
          helpAppleImproveSearch = false;
          showRelatedContent = false;
          searchResults = {
            appStore = false;
            apps = true;
            books = false;
            calculator = true;
            calendar = true;
            contacts = true;
            dictionary = true;
            files = false;
            folders = false;
            games = true;
            iPhoneApps = true;
            mail = true;
            menuItems = true;
            messages = true;
            music = true;
            notes = true;
            phone = true;
            photos = false;
            podcasts = false;
            reminders = false;
            safari = false;
            shortcuts = false;
            systemSettings = true;
            tips = false;
            voiceMemos = false;
          };
        };

        trackpad = {
          pointAndClick.trackingSpeed = 3.0; # was "com.apple.trackpad.scaling"
          scrollAndZoom = {
            rotate = true;
            zoomInOrOut = true;
          };
        };

        wallpaper.wallpaper = ./snapshots/wallpaper;
      };
    };
  };
}
