{
  description = "My nix config";

  inputs = {
    # Nix Packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # MacOS Specific Packages
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Home Manager for user-specific configs
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # homebrew without homebrew
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
    brew-nix = {
      url = "github:BatteredBunny/brew-nix";
      inputs.brew-api.follows = "brew-api";
      inputs.nix-darwin.follows = "nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Agent skills
    agent-skills = {
      url = "path:./programs/skills";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # for MacOS apps fix
    mac-app-util.url = "github:hraban/mac-app-util";
    deploy-rs.url = "github:serokell/deploy-rs";
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Modular flake framework (officially recommended over flake-utils)
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, home-manager, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      imports = [
        # Home Manager flake-parts module (declares flake.homeModules)
        home-manager.flakeModules.home-manager
        # Existing output logic (darwin, nixos, deploy configs)
        ./output.nix
        # Program modules (each program is its own flake-parts module)
        ./programs
      ];
    };
}
