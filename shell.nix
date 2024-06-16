let
  pkgs = import <nixpkgs> { };
in


pkgs.mkShell{
  packages = with pkgs; [
    ocaml
    ocamlPackages.ocaml-lsp
    ocamlPackages.ocamlformat
    opam
    openssl
    pkg-config
    sqlite
    tshark
  ];
  shellHook = ''
    export C_INCLUDE_PATH=${pkgs.zlib.dev}/include:$C_INCLUDE_PATH
    export LIBRARY_PATH=${pkgs.zlib}/lib:$LIBRARY_PATH
    export OPAM_SWITCH_PREFIX=$(pwd)/.opam/5.2.0
    eval $(opam env)
  '';
}
