open Sys
open Unix
open Filename

(* Default values *)
let default_timeout = 60
let default_tshark_path = "/usr/bin/tshark"
let default_steam_path = "/usr/bin/steam"

(* Helper function to parse command line arguments *)
let parse_args () =
  let tshark_path = if Array.length Sys.argv > 1 then Sys.argv.(1) else default_tshark_path
  and steam_path = if Array.length Sys.argv > 2 then Sys.argv.(2) else default_steam_path
  and timeout = if Array.length Sys.argv > 3 then int_of_string Sys.argv.(3) else default_timeout in
  tshark_path, steam_path, timeout
;;

let ssl_key_log_file = temp_file "sslkeylog_" ".txt"
let capture_file = temp_file "capture_" ".pcap"
let filter_expr = "tcp port 443 and http.request.uri contains \"/platformlogin\""
let env_with_ssl_keylog = Array.append (environment ()) [| "SSLKEYLOGFILE=" ^ ssl_key_log_file |]

let start_tshark tshark_path =
  let args = [| "-i"; "any"; "-w"; capture_file; "-f"; filter_expr |] in
  match fork () with 0 -> Unix.execve tshark_path args env_with_ssl_keylog | pid -> pid
;;

let launch_aoe2 steam_path =
  let args = [| "steam://rungameid/813780" |] in
  match fork () with 0 -> Unix.execve steam_path args env_with_ssl_keylog | pid -> pid
;;

let kill_process pid = kill pid sigkill

let extract_credentials tshark_path timeout tshark_pid =
  let start_time = time () in
  let rec loop () =
    if time () -. start_time > float_of_int timeout
    then (
      kill_process tshark_pid;
      None)
    else (
      let pipe_read, pipe_write = pipe () in
      let command = tshark_path in
      let args =
        [| "tshark"
         ; "-r"
         ; capture_file
         ; "-Y"
         ; "http.request.uri contains \"/platformlogin\""
         ; "-T"
         ; "fields"
         ; "-e"
         ; "http.cookie"
        |]
      in
      let pid = Unix.create_process command args Unix.stdin pipe_write Unix.stderr in
      close pipe_write;
      let in_channel = Unix.in_channel_of_descr pipe_read in
      try
        let line = input_line in_channel in
        close_in in_channel;
        if line <> ""
        then (
          kill_process tshark_pid;
          kill_process pid;
          Some line)
        else loop ()
      with
      | End_of_file ->
        close_in in_channel;
        loop ())
  in
  loop ()
;;

let cleanup () =
  remove ssl_key_log_file;
  remove capture_file
;;

let create steam_path tshark_path timeout =
  let tshark_pid = start_tshark tshark_path in
  let aoe2_pid = launch_aoe2 steam_path in
  match extract_credentials tshark_path timeout tshark_pid with
  | Some credentials ->
    Printf.printf "Extracted Credentials: %s\n" credentials;
    kill_process aoe2_pid;
    cleanup ();
    exit 0
  | None ->
    prerr_endline "Failed to extract credentials within the timeout period.";
    kill_process aoe2_pid;
    cleanup ();
    exit 1
;;
