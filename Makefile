.PHONY: all clean

all: _build/opam_solver_proxy.native
	@ :

_build/opam_solver_proxy.native: opam_solver_proxy.ml
	ocamlbuild -tags annot,bin_annot -pkgs cohttp.lwt,cmdliner opam_solver_proxy.native

clean:
	rm -rf _build

aspcud.docker: aspcud.in
	sed -e 's/@SERVER@/solver.opam-remote.8fa3b6b3.svc.dockerapp.io:8080/g' < aspcud.in > aspcud.docker
