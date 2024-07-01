let wait_for_steam steam_path _sslkeylog_path =
  Logger.Sync.info ~m:"Cli" ~f:"wait_for_steam" "Launching steam";
  let read, write = Unix.pipe () in
  let pid =
    Unix.create_process_env
      "steam"
      [| steam_path; "steam://rungameid/813780" |]
      [| "PATH=" ^ Sys.getenv "PATH"; "HOME=" ^ Sys.getenv "HOME"; "DISPLAY=" ^ Sys.getenv "DISPLAY" |]
      write
      write
      write
  in
  Logger.Sync.info ~m:"Cli" ~f:"wait_for_steam" "Steam process running with pid=%d" pid;
  let target = "setup.sh.* Steam runtime environment up-to-date!" in
  let result = Seeker.seek read target (Buffer.create 1024) in
  Logger.Sync.debug ~m:"Cli" ~f:"wait_for_steam" "Closing steam write fd";
  Unix.close write;
  Unix.close read;
  match result with
  | Found _ -> pid
  | NotFound _ ->
    Process.terminate pid;
    Logger.Sync.error ~m:"Cli" ~f:"wait_for_steam" "Exhausted buffer and didn't find '%s'" target;
    failwith ""
  | Error e ->
    Process.terminate pid;
    Logger.Sync.error ~m:"Cli" ~f:"wait_for_steam" "Error while seeking buffer for '%s': %s" target e;
    failwith ""
;;

let launch_tshark_listener tshark_bin sslkeylog_path pcapng_path =
  Logger.Sync.info ~m:"Cli" ~f:"launch_tshark_listener" "Launching tshark listener";
  let read, write = Unix.pipe () in
  let pid =
    Unix.create_process_env
      "sudo"
      [| "sudo"; tshark_bin; "-Q"; "-w"; pcapng_path; "-o"; "ssl.keylog_file:" ^ sslkeylog_path |]
      [||]
      write
      write
      write
  in
  Logger.Sync.info ~m:"Cli" ~f:"launch_tshark_listener" "Tshark listener process running with pid=%d" pid;
  Unix.close write;
  Unix.close read;
  pid
;;

let extract_http_form_value key form =
  let regexp = Str.regexp @@ "Form item: \"" ^ key ^ "\" = \"\\(.*\\)\"" in
  try
    let _ = Str.search_forward regexp form 0 in
    (* Extract matching group and remove spaces *)
    let match_str = Str.matched_group 1 form in
    let no_spaces = Str.global_replace (Str.regexp " ") "" match_str in
    Some no_spaces
  with
  | Not_found -> None
;;

let rec find_credentials_form tshark_bin sslkeylog_path pcapng_path =
  let open Credentials in
  Logger.Sync.debug ~m:"Cli" ~f:"find_credentials_form" "Launching tshark parser";
  let read, write = Unix.pipe () in
  let pid =
    Process.create
      tshark_bin
      [| "-r"; pcapng_path; "-V"; "-o"; "ssl.keylog_file:" ^ sslkeylog_path |]
      write
      write
      write
  in
  Logger.Sync.debug ~m:"Cli" ~f:"find_credentials_form" "Closing tshark pipes";
  Logger.Sync.debug ~m:"Cli" ~f:"find_credentials_form" "Tshark parser process running with pid=%d" pid;
  Unix.close write;
  let output = Io.read_pipe_to_string read in
  let auth = extract_http_form_value "auth" output in
  let alias = extract_http_form_value "alias" output in
  (match auth with
   | Some a -> Logger.Sync.debug ~m:"Cli" ~f:"find_credentials_form" "Extracted auth: %s" a
   | None -> Logger.Sync.warn ~m:"Cli" ~f:"find_credentials_form" "No auth found");
  (match alias with
   | Some a -> Logger.Sync.debug ~m:"Cli" ~f:"find_credentials_form" "Extracted alias: %s" a
   | None -> Logger.Sync.warn ~m:"Cli" ~f:"find_credentials_form" "No alias found");
  Unix.close read;
  if Process.wait pid 5 == false then Process.terminate pid;
  match auth, alias with
  | Some al, Some au ->
    Logger.Sync.info ~m:"Cli" ~f:"find_credentials_form" "Credentials found";
    { alias = al; auth = au }
  | _ ->
    Logger.Sync.warn ~m:"Cli" ~f:"find_credentials_form" "Did not find credentials in capture. Retrying";
    Unix.sleep 1;
    find_credentials_form tshark_bin sslkeylog_path pcapng_path
;;

let run steam_bin tshark_bin sslkeylog_path pcapng_path =
  let steam_pid = None in
  let tshark_pid = None in
  try
    let steam_bin = Io.resolve_symlink steam_bin in
    let tshark_bin = Io.resolve_symlink tshark_bin in
    Logger.Sync.debug ~m:"Cli" ~f:"run" "Resolved steam=%s tshark=%s" steam_bin tshark_bin;
    Io.ensure_file_exists sslkeylog_path;
    Io.ensure_file_exists pcapng_path;
    let steam_pid = Some (wait_for_steam steam_bin sslkeylog_path) in
    Logger.Sync.info ~m:"Cli" ~f:"run" "Steam ready with pid=%d" (match steam_pid with Some s -> s | None -> -1);
    let tshark_pid = Some (launch_tshark_listener tshark_bin sslkeylog_path pcapng_path) in
    Logger.Sync.info ~m:"Cli" ~f:"run" "Tshark ready with pid=%d" (match tshark_pid with Some s -> s | None -> -1);
    Logger.Sync.debug ~m:"Cli" ~f:"run" "Finding credentials";
    let credentials = find_credentials_form tshark_bin sslkeylog_path pcapng_path in
    Logger.Sync.info ~m:"Cli" ~f:"run" "Found credentials for '%s': '%s'" credentials.alias credentials.auth;
    Logger.Sync.info ~m:"Cli" ~f:"run" "Shutting down processes";
    Process.terminate_option steam_pid;
    Process.terminate_option tshark_pid;
    Process.terminate_option @@ Process.pgrep "AoE2DE_s.exe";
    Some credentials
  with
  | e ->
    Logger.Sync.error ~m:"Cli" ~f:"run" "Fatal error %s" (Printexc.to_string e);
    Process.terminate_option steam_pid;
    Process.terminate_option tshark_pid;
    Process.terminate_option @@ Process.pgrep "AoE2DE_s.exe";
    None
;;
