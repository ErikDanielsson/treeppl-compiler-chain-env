args@
{ lib 	     ? import <nixpkgs/lib>
, components ? "miking"
, dev        ? "miking"
, ...
}:
let c = import ./common.nix args;
in c.mkEnv (map (lib.replaceString "-" "") (lib.splitString " " components))
