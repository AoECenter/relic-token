open Relic_token_lib

type seek_result =
  | Found of string
  | NotFound of string
  | Error of string

let rec seek_output fd pattern buffer =
  Logger.Sync.debug "Seeking for /%s/" pattern;
  let buffer_size = 1024 in
  let read_buffer = Bytes.create buffer_size in
  match Unix.read fd read_buffer 0 buffer_size with
  | 0 ->
    Logger.Sync.debug "Seek reached end of buffer";
    NotFound ""
  | bytes_read ->
    Logger.Sync.debug "Read %d bytes" bytes_read;
    Buffer.add_substring buffer (Bytes.to_string read_buffer) 0 bytes_read;
    let contents = Buffer.contents buffer in
    Logger.Sync.debug "Read contents: %s" contents;
    if not @@ String.contains contents '\n'
    then seek_output fd pattern buffer
    else (
      let lines = String.split_on_char '\n' contents in
      let regex = Str.regexp pattern in
      let rec check_lines = function
        | [] ->
          Logger.Sync.debug "Seek reached end of buffer";
          NotFound ""
        | line :: rest ->
          Logger.Sync.debug "Adding line";
          if Str.string_match regex line 0 then Found line else check_lines rest
      in
      match check_lines lines with
      | Found line as found ->
        Logger.Sync.debug "Line found %s" line;
        found
      | NotFound partial ->
        Buffer.clear buffer;
        Buffer.add_string buffer partial;
        seek_output fd pattern buffer
      | _ -> seek_output fd pattern buffer)
  | exception e ->
    Logger.Sync.error "Error while seeking: %s" (Printexc.to_string e);
    Error "Read error"
;;

let rec waitpid_with_timeout pid max =
  match max <= 0 with
  | true -> false
  | false ->
    (match Unix.waitpid [ Unix.WNOHANG ] pid with
     | 0, _ ->
       Unix.sleep 1;
       waitpid_with_timeout pid (max - 1)
     | _, _ -> true
     | exception Unix.Unix_error (Unix.ECHILD, _, _) ->
       Logger.Sync.warn "waitpid with no child process %d; it may have been reaped elsewhere." pid;
       true
     | exception e ->
       Logger.Sync.error "Error while waiting for pid=%d: %s" pid (Printexc.to_string e);
       false)
;;

let terminate_process ?(max = 5) pid =
  Unix.kill pid Sys.sigterm;
  if not (waitpid_with_timeout pid max)
  then (
    Logger.Sync.warn "Process %d did not terminate within %d seconds; sending SIGKILL." pid max;
    Unix.kill pid Sys.sigkill);
  Logger.Sync.info "Process %d terminated." pid
;;

let extract_regex_from_pipe read_end pattern =
  let in_channel = Unix.in_channel_of_descr read_end in
  let output = really_input_string in_channel (in_channel_length in_channel) in
  close_in in_channel;
  let regex = Str.regexp pattern in
  try if Str.search_forward regex output 0 > 0 then Some (Str.matched_string output) else None with
  | Not_found -> None
;;

let wait_for_steam sslkeylog_path =
  Logger.Sync.info "Launching steam";
  let read, write = Unix.pipe () in
  let pid =
    Unix.create_process_env
      "steam"
      [| "steam"; "steam://rungameid/813780" |]
      [| "SSLKEYLOGFILE=" ^ sslkeylog_path
       ; "PATH=" ^ Sys.getenv "PATH"
       ; "HOME=" ^ Sys.getenv "HOME"
       ; "DISPLAY=" ^ Sys.getenv "DISPLAY"
      |]
      write
      write
      write
  in
  Logger.Sync.info "Steam process running with pid=%d" pid;
  let target = "setup.sh.* Steam runtime environment up-to-date!" in
  let result = seek_output read target (Buffer.create 1024) in
  Logger.Sync.debug "Closing steam write fd";
  Unix.close write;
  Unix.close read;
  match result with
  | Found _ -> pid
  | NotFound _ ->
    terminate_process pid;
    Logger.Sync.error "Exhausted buffer and didn't find '%s'" target;
    failwith ""
  | Error e ->
    terminate_process pid;
    Logger.Sync.error "Error while seeking buffer for '%s': %s" target e;
    failwith ""
;;

let launch_tshark_listener sslkeylog_path pcapng_path =
  Logger.Sync.info "Launching tshark listener";
  let pid =
    Unix.create_process_env
      "sudo"
      [| "sudo"
       ; "/nix/store/xxipvlrlwjyybisd0fhfs6ix90i55m9x-wireshark-cli-4.2.5/bin/tshark"
       ; "-Q"
       ; "-w"
       ; pcapng_path
      |]
      [| "SSLKEYLOGFILE=" ^ sslkeylog_path |]
      Unix.stdin
      Unix.stdout
      Unix.stderr
  in
  Logger.Sync.info "Tshark listener process running with pid=%d" pid;
  pid
;;

(* let launch_age_of_empires sslkeylog_path = *)
(*   Logger.Sync.info "Launching Age of Empires II: Definitive Edition"; *)
(*   let _, write = Unix.pipe () in *)
(*   let pid = *)
(*     Unix.create_process_env *)
(*       "steam" *)
(*       [| "steam"; "steam://rungameid/813780" |] *)
(*       [| "SSLKEYLOGFILE=" ^ sslkeylog_path |] *)
(*       write *)
(*       write *)
(*       write *)
(*   in *)
(*   Logger.Sync.info "Age of Empires II: Definitive Edition process running"; *)
(*   pid *)
(* ;; *)

let rec find_credentials_form sslkeylog_path pcapng_path =
  Logger.Sync.info "Launching tshark parser";
  let read, write = Unix.pipe () in
  let pid =
    Unix.create_process_env
      "sudo"
      [| "sudo"
       ; "/nix/store/xxipvlrlwjyybisd0fhfs6ix90i55m9x-wireshark-cli-4.2.5/bin/tshark"
       ; "-r"
       ; pcapng_path
       ; "-Y"
       ; "http.request.method == POST"
       ; "-T"
       ; "fields"
       ; "-e"
       ; "http.file_data"
      |]
      [| "SSLKEYLOGFILE=" ^ sslkeylog_path |]
      write
      write
      write
  in
  Logger.Sync.debug "Closing steam";
  Unix.close write;
  Unix.close read;
  Logger.Sync.info "Tshark parser process running with pid=%d" pid;
  let result = extract_regex_from_pipe read "accountType=STEAM.*" in
  terminate_process pid;
  match result with Some s -> s | None -> find_credentials_form sslkeylog_path pcapng_path
;;

let usage () =
  Logger.Sync.error "Invalid arguments";
  Printf.eprintf "Usage: %s <sslkeylog_path:str> <pcapng_path:str> <wait_seconds:int>\n" Sys.argv.(0);
  exit 1
;;

let () =
  if Array.length Sys.argv <> 4 then usage ();
  let sslkeylog_path = Sys.argv.(1) in
  let pcapng_path = Sys.argv.(2) in
  let wait_seconds = int_of_string Sys.argv.(3) in
  Logger.Sync.debug
    "Initialized with: <sslkeylog_path:%s> <pcapng_path:%s> <wait_seconds:%d>"
    sslkeylog_path
    pcapng_path
    wait_seconds;
  let steam_pid = wait_for_steam sslkeylog_path in
  Logger.Sync.info "Steam ready with pid=%d" steam_pid;
  let tshark_pid = launch_tshark_listener sslkeylog_path pcapng_path in
  Unix.sleep wait_seconds;
  terminate_process tshark_pid;
  Logger.Sync.debug "Finding credentials";
  let cookie = find_credentials_form sslkeylog_path pcapng_path in
  Logger.Sync.info "Found cookie '%s'" cookie;
  Logger.Sync.info "Shutting down processes";
  terminate_process steam_pid
;;
