(* 
 * Copyright (c) 2014-2016 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2014 David Sheets <sheets@alum.mit.edu>
 * Copyright (c) 2014 Romain Calascibetta <romain.calascibetta@gmail.com>
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

open Printf
open Lwt
open Cohttp
open Cohttp_lwt_unix

let html_of_method_not_allowed meth allowed path info = sprintf
  "<html><body><h2>Method Not Allowed</h2>
   <p><b>%s</b> is not an allowed method on <b>%s</b></p>
   <p>Allowed methods on <b>%s</b> are <b>%s</b></p>
   <hr />%s</body></html>" meth path path allowed info

let read_file fname =
  let buf = Buffer.create 4096 in
  Lwt_io.(with_file input fname
    (fun ic ->
      let rec rd () =
        Lwt_io.read ic >>= function
        | "" -> return_unit
        | s -> Buffer.add_string buf s; rd ()
      in rd ()
    ))
  >>= fun () -> return (Buffer.contents buf)

let run_aspcud aspcud_bin tmp_in criteria =
  let tmp_out = Filename.temp_file "aspcud-proxy" ".out" in
  Lwt.finalize
    (fun () ->
      eprintf "%s %s %s\n%!" tmp_in tmp_out criteria;
      Lwt_unix.system (sprintf "%s %s %s %s" aspcud_bin tmp_in tmp_out criteria)
      >>= function
      | Unix.WEXITED 0 -> read_file tmp_out
      | Unix.WEXITED c -> fail (Failure ("aspcud failed with error code " ^ (string_of_int c)))
      | _ -> fail (Failure "aspcud failed")
     )
    (fun () -> Lwt_unix.unlink tmp_out)

let handler ~info ~verbose ~aspcud_bin (ch,conn) req body =
  let uri = Cohttp.Request.uri req in
  let path = Uri.path uri in
  (* Log the request to the console *)
  printf "%s %s %s\n%!"
    (Cohttp.(Code.string_of_method (Request.meth req))) path
    (Sexplib.Sexp.to_string_hum (Conduit_lwt_unix.sexp_of_flow ch));
  (* Get a canonical filename from the URL and docroot *)
  match Request.meth req with
  | `POST -> begin
      match Uri.get_query_param uri "criteria" with
      |	None -> Server.respond_string ~status:`Not_found ~body:"no criteria specified" ()
      | Some cr ->
         let tmp_in = Filename.temp_file "aspcud-proxy" ".in" in
         Lwt.finalize (fun () ->
           let in_stream = Cohttp_lwt_body.to_stream body in
           Lwt_io.(with_file ~mode:output tmp_in
             (fun oc ->
               Lwt_stream.iter_s (Lwt_io.write oc) in_stream >>= fun () ->
               Lwt_io.flush oc)) >>= fun () ->
           run_aspcud aspcud_bin tmp_in cr >>= fun body ->
           Server.respond_string ~status:`OK ~body ()
         ) (fun () -> Lwt_unix.unlink tmp_in)
  end
  | meth ->
    let meth = Cohttp.Code.string_of_method meth in
    let allowed = "POST" in
    let headers = Cohttp.Header.of_list ["allow", allowed] in
    Server.respond_string ~headers ~status:`Method_not_allowed
      ~body:(html_of_method_not_allowed meth allowed path info) ()

let start_server aspcud_bin port host verbose cert key () =
  printf "Listening for HTTP request on: %s %d\n" host port;
  let info = sprintf "Served by Cohttp/Lwt listening on %s:%d" host port in
  let conn_closed (ch,conn) = printf "connection %s closed\n%!"
      (Sexplib.Sexp.to_string_hum (Conduit_lwt_unix.sexp_of_flow ch)) in
  let callback = handler ~info ~verbose ~aspcud_bin in
  let config = Server.make ~callback ~conn_closed () in
  let mode = match cert, key with
    | Some c, Some k -> `TLS (`Crt_file_path c, `Key_file_path k, `No_password, `Port port)
    | _ -> `TCP (`Port port)
  in
  Conduit_lwt_unix.init ~src:host () >>= fun ctx ->
  let ctx = Cohttp_lwt_unix_net.init ~ctx () in
  Server.create ~ctx ~mode config

let lwt_start_server aspcud_bin port host verbose cert key =
  Lwt_main.run (start_server aspcud_bin port host verbose cert key ())

open Cmdliner

let host = 
  let doc = "IP address to listen on." in
  Arg.(value & opt string "0.0.0.0" & info ["s"] ~docv:"HOST" ~doc)

let port =
  let doc = "TCP port to listen on." in
  Arg.(value & opt int 8080 & info ["p"] ~docv:"PORT" ~doc)

let index =
  let doc = "Name of index file in directory." in
  Arg.(value & opt string "index.html" & info ["i"] ~docv:"INDEX" ~doc)

let verb =
  let doc = "Logging output to console." in
  Arg.(value & flag & info ["v"; "verbose"] ~doc)

let ssl_cert =
  let doc = "SSL certificate file." in
  Arg.(value & opt (some string) None & info ["c"] ~docv:"SSL_CERT" ~doc)

let ssl_key =
  let doc = "SSL key file." in
  Arg.(value & opt (some string) None & info ["k"] ~docv:"SSL_KEY" ~doc)

let aspcud_bin =
  let doc = "External solver binary to launch." in
  Arg.(value & opt string "aspcud" & info ["s"] ~docv:"SOLVER" ~doc)

let cmd =
  let doc = "a simple OPAM external solver proxy" in
  let man = [
    `S "DESCRIPTION";
    `P "$(tname) sets up a simple aspcud proxy server to act as a remote solver";
    `S "BUGS";
    `P "Report them via e-mail to <opam-devel@lists.ocaml.org>."
  ] in
  Term.(pure lwt_start_server $ aspcud_bin $ port $ host $ verb $ ssl_cert $ ssl_key),
  Term.info "aspcud-proxy" ~version:"1.0.0" ~doc ~man

let () =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
