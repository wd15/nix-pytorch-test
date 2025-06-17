{
  description = "Environment for DT project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    utils.url = "github:numtide/flake-utils";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, utils, poetry2nix }: (utils.lib.eachSystem ["x86_64-linux" ] (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.cudaSupport = true;
        config.allowUnfree = true;
        overlays = [
          poetry2nix.overlays.default
        ];
      };

      pypkgs = pkgs.python313Packages;

      pypkgs-build-requirements = {
        # hbreader = [ "setuptools" ];
      };

      p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
        builtins.mapAttrs (package: build-requirements:
          (builtins.getAttr package super).overridePythonAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg: if builtins.isString pkg then builtins.getAttr pkg super else pkg) build-requirements);
          })
        ) pypkgs-build-requirements
      );

      args = {
        projectDir = ./.;
        preferWheels = true;
        overrides = p2n-overrides;
        python = pkgs.python313;
        extraPackages = (ps: [ pypkgs.pytorch pkgs.cudatoolkit ]);
      };

      env_ = (pkgs.poetry2nix.mkPoetryEnv args).override (args: { ignoreCollisions = true; });

      env = pkgs.mkShell {
        packages = [ env_ ];
        
        shellHook = ''
         echo "You are now using a NIX environment"
         export CUDA_PATH=${pkgs.cudatoolkit}
         export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libcuda.so.565.77 /usr/lib/x86_64-linux-gnu/libnvidia-ptxjitcompiler.so /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.565.77"
        '';
      };
   in
     rec {
       devShells.default = env;
      }
    )
  );

  nixConfig = {
    extra-substituters = [ "https://cuda-maintainers.cachix.org" "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=" "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };
}
