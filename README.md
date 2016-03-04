opam-solver-proxy
=================

The [OPAM](https://opam.ocaml.org) package manager supports using
[external solvers](https://opam.ocaml.org/doc/Specifying_Solver_Preferences.html)
to calculate efficient upgrades and downgrades of packages.
These external solvers have different ranges of portability, and so
this repository provides support for a Docker container that runs
the popular [aspcud](http://potassco.sourceforge.net/) solver suite
in a container, and exposes it over HTTP.

There is an associated script which replaces the `aspcud` binary
in the client with one that calls the network endpoint instead.

This model is inspired by the [IRILL solver farm](http://cudf-solvers.irill.org/index.html)
which provides a more generic solution that runs multiple solvers
behind the same interface.  This proxy is intended for bulk builds
and other CI systems that make many hundreds of parallel requests
and so need to run beside their associated build containers.

Most people will probably prefer to use the IRILL solver day-to-day, since it
compresses the outgoing request and also load-balances multiple different
solvers to give the optimum solution.  This repo doesn't do any of that...

* Author: Anil Madhavapeddy <anil@recoil.org>
* Questions: <opam-devel@lists.ocaml.org>
* Issues: https://github.com/avsm/opam-solver-proxy
