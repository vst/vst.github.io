{ sources ? import ./nix/sources.nix
, ...
}:

let
  ## Import nixpkgs pinned by niv:
  pkgs = import sources.nixpkgs { };

  ## Prepare the check script:
  dev-check = pkgs.writeShellScriptBin "dev-check" ''
    #!/usr/bin/env bash

    ## Fail on errors:
    set -e

    ## Run `taplo` to check toml files:
    taplo check
    taplo fmt --check

    ## Run prettier to check json, yaml and Markdown files (and maybe more):
    prettier --check .

    ## Run `nil` to check nix files:
    find . -iname "*.nix" -not -path "*/nix/sources.nix" -exec nil diagnostics {} \;

    ## Run `nixpkgs-fmt` to check nix formatting:
    find . -iname "*.nix" -not -path "*/nix/sources.nix" -print0 | xargs --null nixpkgs-fmt --check

    ## Compile the CSS:
    tailwindcss --minify --input styles/main.css --output static/styles/main.css

    ## Build the site:
    zola build
  '';

  ## Prepare the format script:
  dev-format = pkgs.writeShellScriptBin "dev-format" ''
    #!/usr/bin/env bash

    ## Fail on errors:
    set -e

    ## Run `taplo` to format toml files:
    taplo fmt

    ## Run prettier to format json, yaml and Markdown files (and maybe more):
    prettier --write .

    ## Run `nixpkgs-fmt` to format nix files:
    find . -iname "*.nix" -not -path "*/nix/sources.nix" -print0 | xargs --null nixpkgs-fmt

    ## Compile the CSS:
    tailwindcss --minify --input styles/main.css --output static/styles/main.css

    ## Build the site:
    zola build
  '';

  ## Prepare the serve script:
  dev-serve = pkgs.writeShellScriptBin "dev-serve" ''
    #!/usr/bin/env bash

    ## Fail on errors:
    set -e

    ## Compile the CSS:
    tailwindcss --minify --input styles/main.css --output static/styles/main.css

    ## Build the site:
    zola serve
  '';

  ## Prepare the build script:
  dev-build = pkgs.writeShellScriptBin "dev-build" ''
    #!/usr/bin/env bash

    ## Fail on errors:
    set -e

    ## Compile the CSS:
    tailwindcss --minify --input styles/main.css --output static/styles/main.css

    ## Build the site:
    zola build
  '';

  ## Prepare the MD-reformat script:
  dev-md-format = pkgs.writeShellScriptBin "dev-md-format" ''
    #!/usr/bin/env bash

    runhaskell -pgmLmarkdown-unlit content/posts/2024-08-04_abuse-haskell.lhs "''${1}"
  '';

  #########
  ## GHC ##
  #########

  ghc = pkgs.haskellPackages.ghcWithPackages (hpkgs: [
    hpkgs.markdown-unlit
    hpkgs.pandoc
  ]);

  ###########
  ## SHELL ##
  ###########

  ## Prepare Nix shell:
  thisShell = pkgs.mkShell {
    ## Build inputs for development shell:
    buildInputs = [
      ## Build dependencies:
      pkgs.nodejs_20
      pkgs.tailwindcss
      pkgs.zola

      ## Development dependencies:
      ghc
      pkgs.git
      pkgs.marksman
      pkgs.nil
      pkgs.nixpkgs-fmt
      pkgs.nodePackages.prettier
      pkgs.tailwindcss-language-server
      pkgs.taplo

      ## Our custom scripts:
      dev-check
      dev-format
      dev-serve
      dev-build
      dev-md-format
    ];

    NIX_GHC = "${ghc}/bin/ghc";
    NIX_GHCPKG = "${ghc}/bin/ghc-pkg";
    NIX_GHC_DOCDIR = "${ghc}/share/doc/ghc/html";
    NIX_GHC_LIBDIR = "${ghc}/lib/ghc-9.6.5/lib";
  };
in
{
  shell = thisShell;
}
