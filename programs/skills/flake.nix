{
  description = "Agent Skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills-nix = {
      url = "git+https://git.napatsc.com/ns/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Skill sources
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    agent-browser = {
      url = "github:vercel-labs/agent-browser";
      flake = false;
    };
    camoufox-cli = {
      url = "github:bin-huang/camoufox-cli";
      flake = false;
    };
    vercel-skills = {
      url = "github:vercel-labs/skills";
      flake = false;
    };
  };

  outputs = {
    agent-skills-nix,
    mattpocock-skills,
    agent-browser,
    camoufox-cli,
    vercel-skills,
    ...
  }: {
    # Re-export the home-manager module
    homeManagerModules.default = agent-skills-nix.homeManagerModules.default;

    # Expose skill sources for use in the main flake
    inherit
      mattpocock-skills
      agent-browser
      camoufox-cli
      vercel-skills
      ;
  };
}
