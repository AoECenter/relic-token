let rec wait pid max =
  match max <= 0 with
  | true -> false
  | false ->
    (match Unix.waitpid [ Unix.WNOHANG ] pid with
     | 0, _ ->
       Unix.sleep 1;
       wait pid (max - 1)
     | _, _ -> true
     | exception Unix.Unix_error (Unix.ECHILD, _, _) ->
       Logger.Sync.warn
         ~m:"Process"
         ~f:"wait"
         "waitpid with no child process %d; it may have been reaped elsewhere."
         pid;
       true
     | exception e ->
       Logger.Sync.error ~m:"Process" ~f:"wait" "Error while waiting for pid=%d: %s" pid (Printexc.to_string e);
       false)
;;

let create ?(env = [||]) prog args stdin stdout stderr =
  let env_string = Array.fold_left (fun acc var -> acc ^ (if acc = "" then "" else " ") ^ var) "" env in
  let args_string =
    Array.fold_left (fun acc arg -> acc ^ (if acc = "" then "" else " ") ^ Printf.sprintf "\"%s\"" arg) "" args
  in
  Logger.Sync.info ~m:"Process" ~f:"create" "Launching: %s %s %s" env_string prog args_string;
  Unix.create_process_env prog (Array.append [| prog |] args) env stdin stdout stderr
;;

let terminate ?(max = 5) pid =
  try
    Unix.kill pid Sys.sigterm;
    if not (wait pid max)
    then (
      Logger.Sync.warn
        ~m:"Process"
        ~f:"terminate"
        "Process %d did not terminate within %d seconds; sending SIGKILL."
        pid
        max;
      Unix.kill pid Sys.sigkill);
    Logger.Sync.info ~m:"Process" ~f:"terminate" "Process %d terminated." pid
  with
  | Unix.Unix_error (err, _, _) ->
    Logger.Sync.error
      ~m:"Process"
      ~f:"terminate"
      "Failed to terminate process with pid=%d: %s"
      pid
      (Unix.error_message err)
;;

let terminate_option ?(max = 5) pid =
  match pid with
  | Some p -> terminate ~max p
  | None -> Logger.Sync.warn ~m:"Process" ~f:"terminate_option" "Unable to kill unset process"
;;

let handle_signal signal children =
  Logger.Sync.info ~m:"Cli" ~f:"handle_signal" "Received %d, terminating gracefully..." signal;
  List.iter (fun pid -> terminate pid) children;
  exit 1
;;

let setup_signal_handlers children =
  let signals = [ Sys.sigint; Sys.sigterm; Sys.sighup; Sys.sigquit ] in
  List.iter
    (fun signal -> Sys.set_signal signal (Sys.Signal_handle (fun _ -> handle_signal signal children)))
    signals
;;

let pgrep process_name =
  let in_channel = Unix.open_process_in ("pgrep " ^ process_name) in
  try
    let pid = input_line in_channel in
    close_in in_channel;
    Some (int_of_string pid)
  with
  | End_of_file ->
    close_in in_channel;
    None
;;
