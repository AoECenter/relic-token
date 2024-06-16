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
  let result = Seeker.seek read target (Buffer.create 1024) in
  Logger.Sync.debug "Closing steam write fd";
  Unix.close write;
  Unix.close read;
  match result with
  | Found _ -> pid
  | NotFound _ ->
    Process.terminate pid;
    Logger.Sync.error "Exhausted buffer and didn't find '%s'" target;
    failwith ""
  | Error e ->
    Process.terminate pid;
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
  let result = Io.extract_regex_from_pipe read "accountType=STEAM.*" in
  Process.terminate pid;
  match result with Some s -> s | None -> find_credentials_form sslkeylog_path pcapng_path
;;

let extract_credentials query =
  let open Credentials in
  let split_equal str =
    match String.split_on_char '=' str with
    | [ key; value ] -> key, value
    | _ -> failwith "Invalid query string part"
  in
  let split_ampersand str = String.split_on_char '&' str in
  let rec find_value key = function
    | [] -> failwith ("Key " ^ key ^ " not found")
    | (k, v) :: tail -> if k = key then v else find_value key tail
  in
  let parts = List.map split_equal (split_ampersand query) in
  { alias = find_value "alias" parts; auth = find_value "auth" parts }
;;

let run sslkeylog_path pcapng_path wait_seconds =
  Io.ensure_file_exists sslkeylog_path;
  Io.ensure_file_exists pcapng_path;
  let steam_pid = wait_for_steam sslkeylog_path in
  Logger.Sync.info "Steam ready with pid=%d" steam_pid;
  let tshark_pid = launch_tshark_listener sslkeylog_path pcapng_path in
  Unix.sleep wait_seconds;
  Process.terminate tshark_pid;
  Logger.Sync.debug "Finding credentials";
  let cookie = find_credentials_form sslkeylog_path pcapng_path in
  Logger.Sync.info "Found cookie '%s'" cookie;
  Logger.Sync.info "Shutting down processes";
  Process.terminate steam_pid;
  extract_credentials cookie
;;
