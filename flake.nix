{
  description = "Unified development environment with Emacs, Codex, Claude Code, and MCP servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";

    # AI development tools
    codex-nix.url = "github:sadjow/codex-nix?rev=5e4b52c68ad2575dbfb69dfef96abce7f1dd8cb8";
    claude-code-nix.url = "github:sadjow/claude-code-nix?rev=5dfa1244dd5e93dd868719e26d80164dd3b0ba00";
    mcp-haskell.url = "github:o1lo01ol1o/mcp-haskell";
  };

  outputs = { self, nixpkgs, systems, codex-nix, claude-code-nix, mcp-haskell, ... }:
    let
      systemList = import systems;

      forEachSystem = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systemList);

      # Library functions
      lib = {
        # Create an Emacs package with AI development extensions
        mkEmacs = { pkgs }:
          let
            emacsPackages = pkgs.emacsPackagesFor pkgs.emacs-pgtk;
            emacsWithPackages = emacsPackages.emacsWithPackages;
          in
            emacsWithPackages (epkgs: [
              epkgs.vterm
              epkgs.magit
            ]);

        # Get Codex package for system
        mkCodex = { system }:
          let
            codexPackages = codex-nix.packages.${system} or null;
          in
            if codexPackages == null then
              throw "codex: no packages for system ${system}"
            else if codexPackages ? codex then codexPackages.codex
            else if codexPackages ? default then codexPackages.default
            else throw "codex: expected a codex package for system ${system}";

        # Get Claude Code package (if available for system)
        mkClaudeCode = { pkgs, system }:
          let
            claudePackages = claude-code-nix.packages.${system} or null;
          in
            if claudePackages == null then null
            else claudePackages.claude-code or claudePackages.default or null;

        # Create a unified development shell
        # Args:
        #   pkgs: nixpkgs instance
        #   system: target system
        #   baseShell: optional base shell to extend (default: pkgs.mkShell {})
        #   mcpServers: attrset of MCP server configurations
        #   includeEmacs: include Emacs (default: true)
        #   includeCodex: include Codex (default: true)
        #   includeClaudeCode: include Claude Code if available (default: true)
        #   extraPackages: list of additional packages
        mkDevShell = {
          pkgs,
          system,
          baseShell ? null,
          mcpServers ? {},
          includeEmacs ? true,
          includeCodex ? true,
          includeClaudeCode ? true,
          extraPackages ? []
        }:
          let
            emacs = if includeEmacs then [ (lib.mkEmacs { inherit pkgs; }) ] else [];
            codex = if includeCodex then [ (lib.mkCodex { inherit system; }) ] else [];
            claudeCode =
              if includeClaudeCode then
                let cc = lib.mkClaudeCode { inherit pkgs system; };
                in if cc != null then [ cc ] else []
              else [];

            mcpPackages = builtins.attrValues mcpServers;

            allPackages = emacs ++ codex ++ claudeCode ++ mcpPackages ++ extraPackages ++ [
              pkgs.git
              pkgs.git-extras
              pkgs.curl
              pkgs.glab
              pkgs.difftastic
            ];

          in
            if baseShell != null then
              baseShell.overrideAttrs (oldAttrs: {
                buildInputs = (oldAttrs.buildInputs or []) ++ allPackages;
              })
            else
              pkgs.mkShell {
                buildInputs = allPackages;
              };

        # Helper to create MCP ghcid server for Haskell/Obelisk projects
        # Args:
        #   system: target system
        #   ghcid: ghcid package
        #   shell: project shell with GHC environment
        mkMcpGhcid = { system, ghcid, shell }:
          mcp-haskell.lib.mkMcpGhcid {
            inherit system ghcid shell;
          };
      };

    in {
      # Export library functions
      inherit lib;

      # Default packages for each system
      packages = forEachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in {
          emacs = lib.mkEmacs { inherit pkgs; };
          codex = lib.mkCodex { inherit system; };
          claude-code = lib.mkClaudeCode { inherit pkgs system; };
          default = lib.mkEmacs { inherit pkgs; };
        });

      # Example development shells
      devShells = forEachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in {
          # Full AI development environment
          default = lib.mkDevShell {
            inherit pkgs system;
          };

          # Emacs only
          emacs = lib.mkDevShell {
            inherit pkgs system;
            includeCodex = false;
            includeClaudeCode = false;
          };

          # Codex + Claude only (no Emacs)
          ai-tools = lib.mkDevShell {
            inherit pkgs system;
            includeEmacs = false;
          };
        });

      # Templates for integrating into projects
      templates = {
        obelisk-haskell = {
          path = ./templates/obelisk-haskell;
          description = "Integrate emacs-ai-toolkit into an Obelisk Haskell project";
        };
        generic = {
          path = ./templates/generic;
          description = "Integrate emacs-ai-toolkit into any project";
        };
      };
    };
}
