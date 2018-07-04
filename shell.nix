{ nixpkgs ? import <nixpkgs> {} }:
let
  inherit (nixpkgs) pkgs;
in pkgs.stdenv.mkDerivation {
  name = "typhon-env";
  buildInputs = with pkgs; [
    git jq graphviz gist xclip
    tahoelafs
    # elmPackages.elm-make elmPackages.elm-package elmPackages.elm-repl
    # metamath
  ];
}
