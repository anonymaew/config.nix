{ agent-skills, ... }: {
  programs.agent-skills = {
    enable = true;
    skills =
      builtins.listToAttrs (
        map
          (name: {
            inherit name;
            value.source = agent-skills.mattpocock-skills;
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
        agent-browser.source = agent-skills.agent-browser;
        find-skills.source = agent-skills.vercel-skills;
        camoufox-cli.source = agent-skills.camoufox-cli;
        search-engine.source = agent-skills.ns-skills;
      };
  };
}
