# git — version control
# Identity (user.name, user.email, signing key) is set by modules/identity.nix
{ ... }:
{
  flake.homeModules.git =
    { pkgs, config, ... }:
    let
      # Self-hosted forge (Gitea/Forgejo on git.napatsc.com). Authenticated
      # over HTTPS with a personal access token — never SSH.
      forgeHost = "git.napatsc.com";
      forgeUser = "ns";
      # sops-nix decrypts the token at login to this path; the credential
      # helper reads it on demand so the plaintext token never enters the nix
      # store and there is no keychain dependency.
      forgeTokenFile = "${config.xdg.configHome}/sops-nix/secrets/git-napatsc-token";
    in
    {
      home.packages = with pkgs; [ delta ];

      sops.secrets.git-napatsc-token = {
        sopsFile = ../../secrets/darwin.json;
        key = "git-napatsc-token";
        format = "json";
      };

      programs.git = {
        enable = true;
        # `settings` must stay an attrset so it MERGES with the identity
        # fragment in modules/identity.nix (user/signing). The credential
        # helper is a LIST, which toGitINI renders as two `helper` lines in
        # order: the empty one resets any inherited helpers (nixpkgs wires up
        # osxkeychain on darwin) for this host, then the `!` helper supplies
        # the sops-backed token, so a stale keychain item can never win.
        # See gitcredentials(7).
        settings = {
          # git syntax highlight via delta
          core.pager = "delta";
          interactive.diffFilter = "delta --color-only";
          delta = {
            navigate = true; # use n and N to move between diff sections
            dark = true; # or light = true, or omit for auto-detection
          };
          merge.conflictStyle = "zdiff3";
          credential."https://${forgeHost}".helper = [
            ""
            "!f() { test \"$1\" = get && printf 'username=%s\\npassword=%s\\n' '${forgeUser}' \"$(cat ${forgeTokenFile})\"; }; f"
          ];
        };
        lfs.enable = true;
      };
    };
}
