.PHONY: all clean

all: _build/opam_solver_proxy.native
	@ :

_build/opam_solver_proxy.native: opam_solver_proxy.ml
	ocamlbuild -tags annot,bin_annot -pkgs cohttp.lwt,cmdliner opam_solver_proxy.native

clean:
	rm -rf _build
