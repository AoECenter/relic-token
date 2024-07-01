let usage () =
  Relic_token_lib.Logger.Sync.error "Invalid arguments";
  Printf.eprintf "Usage: %s <sslkeylog_path:str> <pcapng_path:str> <steam_bin:str> <tshark_bin:str>\n" Sys.argv.(0);
  exit 1
;;

let () =
  let open Relic_token_lib.Credentials in
  if Array.length Sys.argv <> 5 then usage ();
  let sslkeylog_path = Sys.argv.(1) in
  let pcapng_path = Sys.argv.(2) in
  let steam_bin = Sys.argv.(3) in
  let tshark_bin = Sys.argv.(4) in
  Relic_token_lib.Logger.Sync.debug
    "Initialized with: <sslkeylog_path:%s> <pcapng_path:%s> <steam_bin:%s> <tshark_bin:%s>"
    sslkeylog_path
    pcapng_path
    steam_bin
    tshark_bin;
  match Relic_token_lib.Cli.run steam_bin tshark_bin sslkeylog_path pcapng_path with
  | Some credentials -> Printf.printf "alias=%s\nauth=%s\n" credentials.alias credentials.auth
  | None -> Relic_token_lib.Logger.Sync.error "Unable to aquire credentials"
;;
