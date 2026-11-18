# Restore @earendil-works/pi-schema into the pi-coding-agent closure.
#
# nixpkgs' pi-coding-agent postInstall replaces a HARDCODED list of monorepo
# workspaces in node_modules with real copies, then deletes every remaining
# `packages/*` symlink:
#
#   for ws in chord pi-ai pi-agent-core pi-codemode pi-durable pi-env pi-mcp \
#             pi-telemetry pi-tui; do ... done
#   find "$nm" -type l -lname '*/packages/*' -delete
#
# @earendil-works/pi-schema is a workspace but is NOT on that list, so it was
# deleted while 209 built files still import it at runtime. The parent `pi`
# process hides the gap (its entry bundle inlines the module), but anything
# loaded from an unbundled `dist/` file fails — pi-ai/dist/providers/
# compat-schema.js imports it at line 1, which killed EVERY subagent child
# session with "Cannot find module '@earendil-works/pi-schema'" while launching
# from the same machine (sessions from 2026-11-13 onward).
#
# pi-schema is also published standalone with `dist/` and the `./formats`
# subpath the runtime imports, so the published tarball is a faithful drop-in
# for the `packages/schema` directory — the same technique the upstream
# derivation already uses for `modelData`.
#
# The URL tracks `pkgs.pi-coding-agent.version`, so a nixpkgs bump changes the
# URL and fails on the stale hash instead of silently pairing code with a
# mismatched schema package. Re-run
#   nix store prefetch-file --json --hash-type sha256 <url>
# and paste the new hash when that happens.
{ pkgs }:
let
  version = pkgs.pi-coding-agent.version;

  piSchema = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-schema/-/pi-schema-${version}.tgz";
    hash = "sha256-hh923YROkLalBn3C2Cop/THDLN6PPLAwzYGZ7ZQGt48=";
  };
in
pkgs.pi-coding-agent.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    # Runs after the workspace copies and after the dangling-symlink sweep, so
    # the destination is gone by now and is recreated from the tarball.
    nm="$out/lib/node_modules/pi-monorepo/node_modules"
    ${pkgs.coreutils}/bin/rm -rf "$nm/@earendil-works/pi-schema"
    ${pkgs.coreutils}/bin/mkdir -p "$nm/@earendil-works/pi-schema"
    ${pkgs.gnutar}/bin/tar --extract --gzip \
      --file=${piSchema} \
      --directory="$nm/@earendil-works/pi-schema" \
      --strip-components=1

    # Ship the fix or fail the build — the two entry points the runtime imports.
    for f in dist/index.js dist/formats/index.js; do
      test -f "$nm/@earendil-works/pi-schema/$f" \
        || { echo "pi-schema: $f missing after install" >&2; exit 1; }
    done
  '';
})
