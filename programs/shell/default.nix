# shell — zsh configuration and environment
{ lib, ... }: {
  flake.homeModules.shell =
    { config, ... }:
    let
      # Check if a package exists in home.packages by pname.
      # ONLY use this for things that genuinely break if the package is absent
      # (aliases pointing at a missing binary). Do NOT gate env vars on it:
      # tools installed via uv/pip/brew/download-installer are not in
      # home.packages, so a `hasPackage` guard silently turns the variable off
      # and the tool falls back to littering $HOME (this is exactly how
      # ~/.matplotlib, ~/.jupyter and ~/.sqlite_history survived).
      hasPackage = name: builtins.any (p: (p.pname or p.name or "") == name) config.home.packages;
    in
    {
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        shellAliases = lib.mkMerge [
          # kubectl
          (lib.mkIf (hasPackage "kubectl") {
            k = "kubectl";
            kg = "kubectl get";
            kcf = "kubectl create -f";
            kdf = "kubectl delete -f";
            kaf = "kubectl apply -f";
          })
          # eza
          (lib.mkIf (hasPackage "eza") {
            l = "eza -1al --icons=always --group-directories-first --total-size";
          })
        ];
        # NOTE: no `wget` alias. wget has no HSTS env var (WGET_HSTS_FILE does
        # not exist) and an alias only covers interactive shells, so scripts
        # kept recreating ~/.wget-hsts. WGETRC + `hstsfile` below covers every
        # invocation. Tested against wget 1.25.0.
      };

      home.sessionVariables = {
        # rust
        CARGO_HOME = "${config.xdg.dataHome}/cargo";
        RUSTUP_HOME = "${config.xdg.dataHome}/rustup";
        # nodejs — NPM_CONFIG_USERCONFIG is what keeps ~/.npmrc from returning
        NPM_CONFIG_CACHE = "${config.xdg.cacheHome}/npm";
        NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
        # ansible
        ANSIBLE_CONFIG = "${config.xdg.configHome}/ansible/ansible.cfg";
        # parallel
        PARALLEL_HOME = "${config.xdg.configHome}/parallel";
        # sqlite (read by the sqlite3 CLI)
        SQLITE_HISTORY = "${config.xdg.cacheHome}/sqlite_history";
        # python data stack — installed through uv, so never in home.packages
        MPLCONFIGDIR = "${config.xdg.cacheHome}/matplotlib";
        IPYTHONDIR = "${config.xdg.configHome}/ipython";
        JUPYTER_CONFIG_DIR = "${config.xdg.configHome}/jupyter";
        JUPYTER_DATA_DIR = "${config.xdg.dataHome}/jupyter";
        # tool homes that hardcode $HOME
        ELAN_HOME = "${config.xdg.dataHome}/elan";
        # kubectl reads KUBECACHEDIR (verified on 1.37.2: the discovery/ and
        # http/ trees land there). The earlier note claiming ~/.kube/cache has
        # no env knob was wrong — without this the ~/.kube dotdir comes back.
        KUBECACHEDIR = "${config.xdg.cacheHome}/kube";
        KUBECONFIG = "${config.xdg.configHome}/kube/config";
        # wgetrc directive is `hstsfile` (no underscore); see xdg.configFile below
        WGETRC = "${config.xdg.configHome}/wget/wgetrc";
      };

      # elan's proxies live in $ELAN_HOME/bin (was a hand-written ~/.profile line)
      home.sessionPath = [ "${config.xdg.dataHome}/elan/bin" ];

      xdg.configFile."wget/wgetrc".text = ''
        hstsfile = ${config.xdg.dataHome}/wget/hsts
      '';

      # home.sessionVariables only materializes hm-session-vars.sh, which
      # .zshenv sources — GUI/Finder/launchd-launched tools never see it (that
      # is how ~/.npm/_logs reappeared despite NPM_CONFIG_CACHE). Mirror every
      # session variable into the user's launchd domain at login so those
      # processes stay XDG-clean too. Already-running apps keep their old env;
      # changes apply to apps launched afterwards.
      launchd.agents.session-vars = {
        enable = true;
        config = {
          Label = "org.nix-community.home.session-vars";
          ProgramArguments = [
            "/bin/sh"
            "-c"
            (lib.concatStringsSep "; " (
              lib.mapAttrsToList (
                k: v: "/bin/launchctl setenv ${k} ${lib.escapeShellArg v}"
              ) (
                # Skip values that interpolate other shell variables (e.g. HM's
                # TERMINFO_DIRS = "...:$TERMINFO_DIRS${TERMINFO_DIRS:+:}..."):
                # launchctl has no shell to expand them, so it would store the
                # literal "$TERMINFO_DIRS" text.
                lib.filterAttrs (_: v: !(lib.hasInfix "$" v)) config.home.sessionVariables
              )
            ))
          ];
          RunAtLoad = true;
        };
      };
    };
}
