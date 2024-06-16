let usage () =
  Relic_token_lib.Logger.Sync.error "Invalid arguments";
  Printf.eprintf "Usage: %s <sslkeylog_path:str> <pcapng_path:str> <wait_seconds:int>\n" Sys.argv.(0);
  exit 1
;;

let () =
  if Array.length Sys.argv <> 4 then usage ();
  let sslkeylog_path = Sys.argv.(1) in
  let pcapng_path = Sys.argv.(2) in
  let wait_seconds = int_of_string Sys.argv.(3) in
  Relic_token_lib.Logger.Sync.debug
    "Initialized with: <sslkeylog_path:%s> <pcapng_path:%s> <wait_seconds:%d>"
    sslkeylog_path
    pcapng_path
    wait_seconds;
  let credentials = Relic_token_lib.Cli.run sslkeylog_path pcapng_path wait_seconds in
  Printf.printf "%s %s" credentials.alias credentials.auth
;;
