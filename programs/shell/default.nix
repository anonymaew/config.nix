# shell — zsh configuration and environment
{ lib, ... }: {
  flake.homeModules.shell =
    { config, ... }:
    let
      # Check if a package exists in home.packages by pname
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
          # wget
          (lib.mkIf (hasPackage "wget") {
            wget = "wget --hsts-file=$XDG_DATA_HOME/wget-hsts";
          })
        ];
      };

      home.sessionVariables = lib.mkMerge [
        # rust
        (lib.mkIf (hasPackage "rustup") {
          CARGO_HOME = "${config.xdg.dataHome}/cargo";
          RUSTUP_HOME = "${config.xdg.dataHome}/rustup";
        })
        # wget
        (lib.mkIf (hasPackage "wget") {
          WGET_HSTS_FILE = "${config.xdg.dataHome}/wget/wget-hsts";
        })
        # nodejs
        (lib.mkIf (hasPackage "nodejs") {
          NPM_CONFIG_CACHE = "${config.xdg.cacheHome}/npm";
          NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
        })
        # ansible
        (lib.mkIf (hasPackage "ansible") {
          ANSIBLE_CONFIG = "${config.xdg.configHome}/ansible/ansible.cfg";
        })
        # parallel
        (lib.mkIf (hasPackage "parallel") {
          PARALLEL_HOME = "${config.xdg.configHome}/parallel";
        })
        # sqlite
        (lib.mkIf (hasPackage "sqlite") {
          SQLITE_HISTORY = "${config.xdg.cacheHome}/sqlite_history";
        })
        # matplotlib / jupyter (python packages, check via pname)
        (lib.mkIf (hasPackage "matplotlib") {
          MATPLOTLIBRC = "${config.xdg.configHome}/matplotlib/matplotlibrc";
        })
        (lib.mkIf (hasPackage "jupyter") {
          JUPYTER_DATA_DIR = "${config.xdg.dataHome}/jupyter";
        })
      ];
    };
}
