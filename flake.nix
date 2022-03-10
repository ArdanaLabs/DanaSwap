{
  description = "dUSD";
  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    haskell-nix.inputs.nixpkgs.follows = "haskell-nix/nixpkgs-2105";
    plutus.url = "github:input-output-hk/plutus"; # used for libsodium-vrf
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

  };
  outputs = { self, nixpkgs, haskell-nix, plutus, flake-compat, flake-compat-ci  }@inputs:
    let
      # System types to support.
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      perSystem = nixpkgs.lib.genAttrs supportedSystems;


      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = system: import nixpkgs { inherit system; overlays = [ haskell-nix.overlay ]; inherit (haskell-nix) config; };

      projectFor = system:
        let
          latexEnv = with pkgs; texlive.combine {
                      inherit
                        (texlive)
                        scheme-basic
                        latexmk
                        ;
                      };

          deferPluginErrors = true;
          pkgs = nixpkgsFor system;

          fakeSrc = pkgs.runCommand "real-source" {} ''
            cp -rT ${self} $out
            chmod u+w $out/cabal.project
            cat $out/cabal-haskell.nix.project >> $out/cabal.project
          '';
        in
        (nixpkgsFor system).haskell-nix.cabalProject' {
          src = fakeSrc.outPath;
          compiler-nix-name = "ghc8107";
          cabalProjectFileName = "cabal.project";
          modules = [{
            packages = {
              marlowe.flags.defer-plugin-errors = deferPluginErrors;
              plutus-use-cases.flags.defer-plugin-errors = deferPluginErrors;
              plutus-ledger.flags.defer-plugin-errors = deferPluginErrors;
              plutus-contract.flags.defer-plugin-errors = deferPluginErrors;
              cardano-crypto-praos.components.library.pkgconfig =
                nixpkgs.lib.mkForce [ [ (import plutus { inherit system; }).pkgs.libsodium-vrf ] ];
              cardano-crypto-class.components.library.pkgconfig =
                nixpkgs.lib.mkForce [ [ (import plutus { inherit system; }).pkgs.libsodium-vrf ] ];
            };
          }];
          shell = {
            withHoogle = true;

            exactDeps = true;

            # We use the ones from Nixpkgs, since they are cached reliably.
            # Eventually we will probably want to build these with haskell.nix.
            nativeBuildInputs = [ latexEnv pkgs.entr pkgs.cabal-install pkgs.hlint pkgs.haskellPackages.fourmolu ];

            additional = ps: [
              ps.apropos
              ps.apropos-tx
              ps.plutarch
              ps.sydtest
              ps.sydtest-hedgehog
            ];
          };
          sha256map = {
            "https://github.com/mlabs-haskell/apropos"."5d98c585168af9063f27ffbbe2787529bc846efc"
              = "sha256-qJvhg8E9McOSq/eJyqd6CD99LYSyW+esmELqbMoRlNU=";
            "https://github.com/mlabs-haskell/apropos-tx"."d5a90656ad77a48d2291748e1bb5ae072c85eaa4"
              = "sha256-SkWvW7EyI94BoFWvzyk+MsTNd3eomRlwaBovIQtI71o=";
            "https://github.com/Plutonomicon/plutarch"."aecc2050eb63ff0041576473aa3193070fe91314"
              = "sha256-pVvSa4fBoKXCdCu/NGduoKhr1/gGESCmj/Tr9Y5l9B4=";
            "https://github.com/input-output-hk/plutus.git"."6d8d25d1e84b2a4278da1036aab23da4161b8df8"
              = "o8m86TkI1dTo74YbE9CPPNrBfSDSrf//DMq+v2+woEY=";
            "https://github.com/Quid2/flat.git"."ee59880f47ab835dbd73bea0847dab7869fc20d8"
              = "lRFND+ZnZvAph6ZYkr9wl9VAx41pb3uSFP8Wc7idP9M=";
            "https://github.com/input-output-hk/cardano-crypto.git"."07397f0e50da97eaa0575d93bee7ac4b2b2576ec"
              = "oxIOVlgm07FAEmgGRF1C2me9TXqVxQulEOcJ22zpTRs=";
            "https://github.com/input-output-hk/cardano-base"."78b3928391b558fb1750228f63301ec371f13528"
              = "pBUTTcenaSLMovHKGsaddJ7Jh3okRTrtu5W7Rdu6RM4=";
            "https://github.com/input-output-hk/cardano-prelude"."fd773f7a58412131512b9f694ab95653ac430852"
              = "BtbT5UxOAADvQD4qTPNrGfnjQNgbYNO4EAJwH2ZsTQo=";
            "https://github.com/input-output-hk/Win32-network"."3825d3abf75f83f406c1f7161883c438dac7277d"
              = "Hesb5GXSx0IwKSIi42ofisVELcQNX6lwHcoZcbaDiqc=";
            "https://github.com/Srid/sydtest"."9c6c7678f7aabe22e075aab810a6a2e304591d24"
              = "sha256-P6ZwwfFeN8fpi3fziz9yERTn7BfxdE/j/OofUu+4GdA=";
            "https://github.com/Srid/autodocodec"."42b42a7407f33c6c74fa4e8c84906aebfed28daf"
              = "sha256-X1TNZlmO2qDFk3OL4Z1v/gzvd3ouoACAiMweutsYek4=";
            "https://github.com/Srid/validity"."f7982549b95d0ab727950dc876ca06b1862135ba"
              = "sha256-dpMIu08qXMzy8Kilk/2VWpuwIsfqFtpg/3mkwt5pdjA=";
          };
        };

    in {
      ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
        flake = self;
        systems = [ "x86_64-linux" ];
      };

      project = perSystem projectFor;
      flake = perSystem (system: (projectFor system).flake {});

      # this could be done automatically, but would reduce readability
      packages = perSystem (system: self.flake.${system}.packages);
      checks = perSystem (system: self.flake.${system}.checks);
      check = perSystem (system:
        (nixpkgsFor system).runCommand "combined-test" {
          nativeBuildInputs = builtins.attrValues self.checks.${system};
        } "touch $out"
      );

      devShell = perSystem (system: self.flake.${system}.devShell);

      apps = perSystem (system:
        let
          pkgs = (perSystem nixpkgsFor)."${system}";
        in
        {
          feedback-loop = {
            type = "app";
            program = "${pkgs.writeShellScript "feedback-loop" ''
              echo "test-plan.tex" | ${pkgs.entr}/bin/entr latexmk -pdf test-plan.tex
            ''}";
          };
        });
  };
}
