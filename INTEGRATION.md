# Integration Guide

## Integrating into Cleverbeach/Plast

### Step 1: Add as Flake Input

Edit `nix/flake.nix` to add the toolkit:

```nix
{
  description = "CI flake inputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    claude-code-flake.url = "path:./claude-code";
    # Add emacs-ai-toolkit
    emacs-ai-toolkit.url = "github:YOUR-USERNAME/emacs-ai-toolkit";
  };

  outputs = { self, nixpkgs, claude-code-flake, emacs-ai-toolkit, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in {
      # Expose MCP servers as packages
      packages = forAllSystems (system:
        let
          obelisk = import ../.obelisk/impl {
            inherit system;
            useGHC810 = true;
            iosSdkVersion = "16.1";
            config.allowBroken = true;
            config.android_sdk.accept_license = true;
            terms.security.acme.acceptTerms = true;
          };

          project = import ../default.nix { inherit system; };

          ghcid =
            if obelisk.nixpkgs ? ghcid then obelisk.nixpkgs.ghcid
            else if obelisk.nixpkgs.haskellPackages ? ghcid then obelisk.nixpkgs.haskellPackages.ghcid
            else throw "expected ghcid in obelisk nixpkgs";

          mcpGhcid = emacs-ai-toolkit.lib.mkMcpGhcid {
            inherit system ghcid;
            shell = project.shells.ghc;
          };

        in {
          inherit mcpGhcid;
          # Keep existing packages
          claude-code = claude-code-flake.packages.${system}.claude-code;
        });

      # Development shells
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          project = import ../default.nix { inherit system; };

          # AI development shell
          aiDevShell = emacs-ai-toolkit.lib.mkDevShell {
            inherit pkgs system;
            baseShell = project.shells.ghc;
            mcpServers = {
              mcpGhcid = self.packages.${system}.mcpGhcid;
            };
          };

        in {
          # Main AI development shell
          default = aiDevShell;

          # Keep existing shells
          claude-code = claude-code-flake.devShells.${system}.default;
        });
    };
}
```

### Step 2: Simplify Shell Files

You can now simplify `nix/shell-codex.nix`:

```nix
{ system ? builtins.currentSystem }:
let
  flake = builtins.getFlake "path:./nix";  # or use your remote flake
in
  flake.devShells.${system}.default
```

And `nix/shell-emacs.nix`:

```nix
{ system ? builtins.currentSystem }:
let
  flake = builtins.getFlake "path:./nix";
  project = import ../default.nix { inherit system; };
in
  flake.outputs.emacs-ai-toolkit.lib.mkDevShell {
    pkgs = import flake.inputs.nixpkgs { inherit system; };
    inherit system;
    baseShell = project.shells.ghc;
    includeCodex = false;
    includeClaudeCode = false;
  }
```

### Step 3: Update `.codex/config.toml`

```toml
model = "claude-sonnet-4"
model_provider = "anthropic"

[mcp_servers.ghcid]
startup_timeout_sec = 60
command = "nix"
args = [
  "develop",
  "./nix#mcpGhcid",  # Now points to flake output
  "--command",
  "mcp-ghcid"
]

[projects."/Users/timpierson/Work/cleverbeach"]
trust_level = "trusted"
```

### Step 4: Build and Use

```bash
# Build MCP server
nix build ./nix#mcpGhcid

# Enter AI dev shell
nix develop ./nix

# Or use specific shells
nix develop -f nix/shell-codex.nix
nix develop -f nix/shell-emacs.nix

# Use Codex
export CODEX_HOME=.codex
codex

# Use Claude Code
claude
```

## Benefits

1. **Unified Configuration**: All AI tools in one place
2. **Version Control**: Flake pins ensure reproducibility
3. **Reusability**: Same flake works across projects
4. **Modularity**: Pick and choose which tools to include
5. **MCP Extensibility**: Easy to add custom MCP servers

## Migration Path

### Phase 1: Parallel Setup
- Keep existing `shell-codex.nix` and `shell-emacs.nix`
- Add new flake-based shells alongside them
- Test the new setup

### Phase 2: Switch Over
- Update scripts/workflows to use new flake outputs
- Remove old shell files

### Phase 3: Extend
- Add custom MCP servers
- Share the flake across projects
- Push to GitHub for team use

## Custom MCP Servers

Add new servers to your project's flake:

```nix
packages = forAllSystems (system:
  let
    pkgs = import nixpkgs { inherit system; };

    # Custom file system MCP server
    mcpFilesystem = pkgs.writeShellScriptBin "mcp-filesystem" ''
      exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-filesystem \
        /Users/timpierson/Work/cleverbeach
    '';

    # Custom git MCP server
    mcpGit = pkgs.writeShellScriptBin "mcp-git" ''
      cd /Users/timpierson/Work/cleverbeach
      exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-git
    '';

  in {
    inherit mcpGhcid mcpFilesystem mcpGit;
  });
```

Then reference in `.codex/config.toml`:

```toml
[mcp_servers.filesystem]
command = "nix"
args = ["develop", "./nix#mcpFilesystem", "--command", "mcp-filesystem"]

[mcp_servers.git]
command = "nix"
args = ["develop", "./nix#mcpGit", "--command", "mcp-git"]
```

## Next Steps

1. Push `emacs-ai-toolkit` to GitHub
2. Update cleverbeach and plast to use it as input
3. Test MCP server integration
4. Document project-specific customizations
5. Share with team
