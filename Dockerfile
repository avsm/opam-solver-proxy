FROM ocaml/opam:alpine-3.5_ocaml-4.03.0
RUN opam pin add -n opam-solver-proxy git://github.com/avsm/opam-solver-proxy
RUN opam depext -i opam-solver-proxy
EXPOSE 8080
ENTRYPOINT ["opam","config","exec","--","opam-solver-proxy"]
