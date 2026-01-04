{
  description = "Generic project with AI development tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    emacs-ai-toolkit.url = "github:o1lo01ol1o/emacs-ai-toolkit";
  };

  outputs = { self, nixpkgs, emacs-ai-toolkit, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];

      forEachSystem = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systems);
    in {
      devShells = forEachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # Define your MCP servers here
          # Example: file system MCP server
          # mcpServers = {
          #   filesystem = pkgs.writeShellScriptBin "mcp-filesystem" ''
          #     exec ${pkgs.nodejs}/bin/node ${./mcp-servers/filesystem.js}
          #   '';
          # };

        in {
          default = emacs-ai-toolkit.lib.mkDevShell {
            inherit pkgs system;
            # mcpServers = mcpServers;
            extraPackages = [
              # Add your project-specific tools here
              # pkgs.nodejs
              # pkgs.python3
            ];
          };
        });
    };
}
