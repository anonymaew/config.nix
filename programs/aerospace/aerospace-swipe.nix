# aerospace-swipe — trackpad swipe gestures for AeroSpace
#
# Upstream is a bare Makefile build (clang + macOS system frameworks, no
# package.json/configure). We call out to the same targets under nixpkgs'
# darwin stdenv and ad-hoc codesign both artifacts with the accessibility
# entitlement (CGEventTap requires it).
#
# Order matters: `make bundle` must run before signing the raw `swipe`
# binary — bundle signing embeds an unsigned copy into the .app and refuses
# to overwrite a signature that is already present.
{ lib, stdenv, src }:
stdenv.mkDerivation {
  pname = "aerospace-swipe";
  version = "0-unstable-2026-07-19";

  inherit src;

  # Post-install stripping invalidates the ad-hoc codesign signatures
  # (same reason nixpkgs' yabai sets dontStrip), so keep the binaries as-is.
  dontStrip = true;

  buildPhase = ''
    runHook preBuild
    # codesign lives in /usr/bin; scope PATH per command so the nixpkgs
    # strip/debug phases still resolve GNU find/cut.
    PATH=/usr/bin:/bin:$PATH make all
    PATH=/usr/bin:/bin:$PATH make bundle
    PATH=/usr/bin:/bin:$PATH codesign --entitlements accessibility.entitlements --sign - swipe
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/Applications
    install -m755 swipe $out/bin/aerospace-swipe
    cp -R AerospaceSwipe.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "Switch AeroSpace workspaces by swiping on the trackpad";
    homepage = "https://github.com/acsandmann/aerospace-swipe";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}