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

    # Only Napat's own skills are installed. Upstream collections
    # (mattpocock/skills, vercel-labs/*) are no longer vendored: add a skill
    # back by adding its flake input here and mapping it in `skillSources`.
    ns-skills = {
      url = "git+https://git.napatsc.com/ns/skills";
      flake = false;
    };
  };

  outputs =
    {
      agent-skills-nix,
      ns-skills,
      ...
    }:
    let
      skillSources = {
        implementor.source = ns-skills;
      };
    in
    {
      # Merged home-manager module: imports the remote agent-skills-nix module
      # (which defines options) then applies the local skill configuration.
      homeManagerModules.default = _: {
        imports = [ agent-skills-nix.homeManagerModules.default ];
        programs.agent-skills = {
          enable = true;
          skills = skillSources;
        };
      };
    };
}
