{
  description = "Obelisk project with AI development tools";

  inputs = {
    # Your project's existing inputs
    # nixpkgs.url = "...";
    # obelisk.url = "...";

    # Add emacs-ai-toolkit
    emacs-ai-toolkit.url = "github:o1lo01ol1o/emacs-ai-toolkit";
  };

  outputs = { self, emacs-ai-toolkit, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];

      forEachSystem = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systems);
    in {
      # Build MCP servers as packages
      packages = forEachSystem (system:
        let
          # Your project setup
          obelisk = import ./.obelisk/impl {
            inherit system;
            useGHC810 = true;
            # ... other obelisk config
          };

          project = import ./default.nix { inherit system; };

          # Get ghcid from your obelisk nixpkgs
          ghcid =
            if obelisk.nixpkgs ? ghcid then
              obelisk.nixpkgs.ghcid
            else if obelisk.nixpkgs.haskellPackages ? ghcid then
              obelisk.nixpkgs.haskellPackages.ghcid
            else
              throw "expected ghcid in obelisk nixpkgs";

          # Create MCP ghcid server
          mcpGhcid = emacs-ai-toolkit.lib.mkMcpGhcid {
            inherit system ghcid;
            shell = project.shells.ghc;
          };
        in {
          inherit mcpGhcid;
        });

      # Development shells
      devShells = forEachSystem (system:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # Your project
          project = import ./default.nix { inherit system; };

          # Get the MCP server
          mcpGhcid = self.packages.${system}.mcpGhcid;

          # Create AI dev shell extending your project shell
          aiDevShell = emacs-ai-toolkit.lib.mkDevShell {
            inherit pkgs system;
            baseShell = project.shells.ghc;
            mcpServers = {
              inherit mcpGhcid;
            };
          };
        in {
          default = aiDevShell;
          ghc = project.shells.ghc; # Keep original shell available
        });
    };
}
