{
  description = "A collection of custom packages organized in folders";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        importPackage = name: pkgs.callPackage (./. + "/${name}/package.nix") { };

        getSubDirs =
          dir: with builtins; filter (n: (readDir dir).${n} == "directory") (attrNames (readDir dir));

        packageNames = getSubDirs ./.;

        customPackages = builtins.listToAttrs (
          map (name: {
            inherit name;
            value = importPackage name;
          }) packageNames
        );

      in
      {
        packages = customPackages // {
          default = customPackages.${builtins.head packageNames};
        };

        legacyPackages = customPackages;

        overlays.default = final: prev: customPackages;
      }
    );
}
