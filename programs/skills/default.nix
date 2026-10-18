# skills — agent skills configuration
{ inputs, ... }:
let
  sources = inputs.agent-skills;
in
{
  flake.homeModules.skills = { ... }: {
    programs.agent-skills = {
      enable = true;
      skills =
        builtins.listToAttrs (
          map
            (name: {
              inherit name;
              value.source = sources.mattpocock-skills;
            })
            [
              "codebase-design"
              "domain-modeling"
              "grill-me"
              "grill-with-docs"
              "handoff"
              "improve-codebase-architecture"
              "tdd"
              "teach"
              "writing-great-skills"
            ]
        )
        // {
          agent-browser.source = sources.agent-browser;
          find-skills.source = sources.vercel-skills;
          camoufox-cli.source = sources.camoufox-cli;
          search-engine.source = sources.ns-skills;
        };
    };
  };
}
