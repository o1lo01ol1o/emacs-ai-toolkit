# Emacs AI Toolkit

A unified Nix flake providing Emacs, Codex, Claude Code, and MCP server infrastructure for AI-assisted development.

## Features

- **Emacs (Doom-compatible)**: emacs-pgtk with vterm and magit
- **Codex**: AI-powered code assistant with MCP server integration
- **Claude Code**: Command-line interface for Claude AI
- **MCP Server Framework**: Integrate arbitrary Model Context Protocol servers
- **Modular**: Use all tools together or pick specific components
- **Cross-platform**: Works on Linux and macOS (Darwin)

## Quick Start

### As a Flake Input

Add to your project's `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    emacs-ai-toolkit.url = "github:YOUR-USERNAME/emacs-ai-toolkit";
  };

  outputs = { self, nixpkgs, emacs-ai-toolkit, ... }:
    {
      devShells.x86_64-linux.default =
        emacs-ai-toolkit.lib.mkDevShell {
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          system = "x86_64-linux";
        };
    };
}
```

### Standalone Usage

```bash
# Enter development shell with all tools
nix develop github:YOUR-USERNAME/emacs-ai-toolkit

# Or just Emacs
nix develop github:YOUR-USERNAME/emacs-ai-toolkit#emacs

# Or just AI tools (Codex + Claude)
nix develop github:YOUR-USERNAME/emacs-ai-toolkit#ai-tools
```

## Library Functions

### `mkDevShell`

Create a unified development shell with AI tools.

**Parameters:**
- `pkgs`: nixpkgs instance
- `system`: target system (e.g., "x86_64-linux")
- `baseShell`: (optional) existing shell to extend
- `mcpServers`: (optional) attrset of MCP server packages
- `includeEmacs`: (default: true) include Emacs
- `includeCodex`: (default: true) include Codex
- `includeClaudeCode`: (default: true) include Claude Code
- `extraPackages`: (optional) list of additional packages

**Example:**
```nix
emacs-ai-toolkit.lib.mkDevShell {
  inherit pkgs system;
  baseShell = myProject.shells.ghc;
  mcpServers = {
    ghcid = mcpGhcidPackage;
  };
  extraPackages = [ pkgs.nodejs pkgs.python3 ];
}
```

### `mkMcpGhcid`

Create an MCP ghcid server for Haskell projects (requires ghcid and project shell).

**Parameters:**
- `system`: target system
- `ghcid`: ghcid package
- `shell`: project shell with GHC environment

**Example:**
```nix
mcpGhcid = emacs-ai-toolkit.lib.mkMcpGhcid {
  inherit system ghcid;
  shell = project.shells.ghc;
};
```

### `mkEmacs`

Create an Emacs package with AI development extensions.

**Parameters:**
- `pkgs`: nixpkgs instance

**Example:**
```nix
emacs = emacs-ai-toolkit.lib.mkEmacs { inherit pkgs; };
```

### `mkCodex`

Get the Codex package for a system.

**Parameters:**
- `system`: target system

**Example:**
```nix
codex = emacs-ai-toolkit.lib.mkCodex { inherit system; };
```

### `mkClaudeCode`

Get the Claude Code package for a system (returns null if unavailable).

**Parameters:**
- `pkgs`: nixpkgs instance
- `system`: target system

**Example:**
```nix
claudeCode = emacs-ai-toolkit.lib.mkClaudeCode { inherit pkgs system; };
```

## Integration Examples

### Obelisk Haskell Project

See `templates/obelisk-haskell/flake.nix` for a complete example.

Key steps:
1. Add `emacs-ai-toolkit` as a flake input
2. Build MCP servers (like `mcpGhcid`) as packages
3. Create dev shell extending your project shell
4. Configure Codex to use the MCP servers

```nix
# In your flake outputs
packages.${system}.mcpGhcid = emacs-ai-toolkit.lib.mkMcpGhcid {
  inherit system ghcid;
  shell = project.shells.ghc;
};

devShells.${system}.default = emacs-ai-toolkit.lib.mkDevShell {
  inherit pkgs system;
  baseShell = project.shells.ghc;
  mcpServers = {
    mcpGhcid = self.packages.${system}.mcpGhcid;
  };
};
```

### Generic Project

See `templates/generic/flake.nix` for a complete example.

```nix
devShells.${system}.default = emacs-ai-toolkit.lib.mkDevShell {
  inherit pkgs system;
  extraPackages = [
    pkgs.nodejs
    pkgs.python3
  ];
};
```

### Custom MCP Servers

You can add arbitrary MCP servers by creating packages:

```nix
mcpServers = {
  # Node.js-based MCP server
  myServer = pkgs.writeShellScriptBin "my-mcp-server" ''
    exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-filesystem /allowed/path
  '';

  # Python-based MCP server
  pythonServer = pkgs.writeShellScriptBin "python-mcp" ''
    exec ${pkgs.python3}/bin/python ${./mcp-servers/my-server.py}
  '';
};
```

## Codex Configuration

Create `.codex/config.toml` in your project root:

```toml
model = "claude-sonnet-4"
model_provider = "anthropic"

# Reference MCP servers built by the flake
[mcp_servers.ghcid]
startup_timeout_sec = 60
command = "nix"
args = [
  "develop",
  "./nix#mcpGhcid",  # Path to your flake's mcpGhcid output
  "--command",
  "mcp-ghcid"
]

[projects."/path/to/your/project"]
trust_level = "trusted"
```

See `templates/codex-config.toml` for more examples.

## Usage Workflow

1. **Build MCP servers** (if needed):
   ```bash
   nix build ./nix#mcpGhcid
   ```

2. **Enter development shell**:
   ```bash
   nix develop
   ```

3. **Start Emacs**:
   ```bash
   emacs
   ```

4. **Use Codex**:
   ```bash
   export CODEX_HOME=.codex
   codex
   ```

5. **Use Claude Code**:
   ```bash
   claude
   ```

## Doom Emacs Integration

This toolkit provides Emacs packages but relies on your existing Doom Emacs configuration in `~/.doom.d/`.

Key features to include in your Doom config:
- Project-based theme selection
- Magit diff annotation workflow
- Annotate-mode for code review
- VTerm terminal integration

See the documentation in your project's `docs/emacs-dev-setup.md` for Doom configuration examples.

## Templates

Generate starter configurations:

```bash
# For Obelisk Haskell projects
nix flake init -t github:YOUR-USERNAME/emacs-ai-toolkit#obelisk-haskell

# For generic projects
nix flake init -t github:YOUR-USERNAME/emacs-ai-toolkit#generic
```

## Troubleshooting

### MCP Server Handshake Fails

Ensure MCP servers are built explicitly:
```bash
nix build ./nix#mcpGhcid
```

Building on systems with limited memory:
```bash
nix build ./nix#mcpGhcid --cores 1 --max-jobs 1
```

### Codex Can't Find MCP Servers

Check that the `command` and `args` in `.codex/config.toml` match your flake outputs:
```bash
# Test the command directly
nix develop ./nix#mcpGhcid --command mcp-ghcid
```

### Claude Code Not Available

Claude Code is currently Linux-only. On macOS, it will be excluded automatically (check `includeClaudeCode` parameter).

## Development

To modify this toolkit:

```bash
git clone https://github.com/YOUR-USERNAME/emacs-ai-toolkit
cd emacs-ai-toolkit
nix develop
```

Run checks:
```bash
nix flake check
```

## License

MIT

## Contributing

Contributions welcome! Please submit PRs or open issues on GitHub.
