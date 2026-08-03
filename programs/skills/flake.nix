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
    ns-skills = {
      url = "git+https://git.napatsc.com/ns/skills";
      flake = false;
    };
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

  outputs =
    {
      agent-skills-nix,
      ns-skills,
      mattpocock-skills,
      agent-browser,
      camoufox-cli,
      vercel-skills,
      ...
    }:
    let
      skillSources = {
        codebase-design.source = mattpocock-skills;
        domain-modeling.source = mattpocock-skills;
        grill-me.source = mattpocock-skills;
        grill-with-docs.source = mattpocock-skills;
        handoff.source = mattpocock-skills;
        improve-codebase-architecture.source = mattpocock-skills;
        tdd.source = mattpocock-skills;
        teach.source = mattpocock-skills;
        writing-great-skills.source = mattpocock-skills;
        agent-browser.source = agent-browser;
        find-skills.source = vercel-skills;
        camoufox-cli.source = camoufox-cli;
        search-engine.source = ns-skills;
      };
    in
    {
      # Merged home-manager module: imports the remote agent-skills-nix module
      # (which defines options) then applies the local skill configuration.
      homeManagerModules.default = { ... }: {
        imports = [ agent-skills-nix.homeManagerModules.default ];
        programs.agent-skills = {
          enable = true;
          skills = skillSources;
        };
      };

      # Expose skill sources for use in the main flake
      inherit
        ns-skills
        mattpocock-skills
        agent-browser
        camoufox-cli
        vercel-skills
        ;
    };
}
