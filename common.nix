args@
{ lib             ? import <nixpkgs/lib>
, pkgs            ? import <nixpkgs> {}
, compilerChain ?
    if builtins.pathExists ./local.nix
    then (import ./local.nix).compilerChain
    else throw "Create ${toString ./local.nix} with { compilerChain = \"/path/to/compilers\"; }"
, miking          ? "${compilerChain}/miking"
, ocamlMikingPath ? "${miking}/build/lib"
, mi_stats        ? "${compilerChain}/mi-stats"
, mikingdppl      ? "${compilerChain}/miking-dppl"
, treeppl         ? "${compilerChain}/treeppl"
, dev             ? "miking"
, ...
}:
let mcoreLibsPaths = [
    { name = "stdlib";   path = "${miking}/src/stdlib"; }
    { name = "mi-stats"; path = "${mi_stats}/src/lib"; }
    { name = "coreppl";  path = "${mikingdppl}/coreppl/src"; }
    { name = "treeppl";  path = "${treeppl}/lib"; }
  ];
  mcoreLibs = lib.concatMapStringsSep ":" ({ name, path }: "${name}=${path}") mcoreLibsPaths;

  system = args.system or builtins.currentSystem;

  components = {
    miking = {
      src = miking;
      build = args.mikingBuild or "${miking}/build";
      bins = [ "mi" ];
      ocamlPath = ocamlMikingPath;
    };
    mikingdppl = {
      src = mikingdppl;
      build = args.mikingdpplBuild or "${mikingdppl}/build";
      bins = [ "cppl" ];
    };
    treeppl    = {
      src = treeppl;
      build = args.treepplBuild or "${treeppl}/build";
      bins = [ "tpplc" ];
    };
  };

  devShellOf = c:
    (builtins.getFlake "git+file://${c.src}?dir=misc/packaging").devShells.${system}.default;

  envVarOf = shell: var: lib.removeSuffix "\n" (builtins.readFile
    (shell.overrideAttrs (_: {
      name = "${var}-capture";
      buildCommand = ''printf '%s' "${"$"}${var}" > $out'';
    })));

  wrap = c:
    let
      shell = devShellOf c;
      ocamlPath = lib.concatStringsSep ":"
        (lib.optional (c ? ocamlPath) c.ocamlPath ++ [ (envVarOf shell "OCAMLPATH") ]);
      toolPath = envVarOf shell "PATH";
    in
    map (b: pkgs.writeShellScriptBin b ''
      export MCORE_LIBS="${mcoreLibs}"
      export OCAMLPATH="${ocamlPath}"
      export PATH="${toolPath}:$PATH"
      exec "${c.build}/${b}" "$@"
    '') c.bins;

  mkEnv = names:
    let
      cs       = map (n: components.${n}) (lib.filter (n: lib.elem n names) (lib.attrNames components));
      wrappers = lib.concatMap wrap cs;
    in
    if dev == null
    then pkgs.mkShell { packages = wrappers; }
    else (devShellOf components.${dev}).overrideAttrs (old: {
      shellHook = (old.shellHook or "") + ''
        export PATH="${lib.makeBinPath wrappers}:$PATH"
      '';
    });
in
{ inherit compilerChain miking ocamlMikingPath mikingdppl treeppl mcoreLibs mkEnv; }
