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
       Logger.Sync.warn "waitpid with no child process %d; it may have been reaped elsewhere." pid;
       true
     | exception e ->
       Logger.Sync.error "Error while waiting for pid=%d: %s" pid (Printexc.to_string e);
       false)
;;

let terminate ?(max = 5) pid =
  Unix.kill pid Sys.sigterm;
  if not (wait pid max)
  then (
    Logger.Sync.warn "Process %d did not terminate within %d seconds; sending SIGKILL." pid max;
    Unix.kill pid Sys.sigkill);
  Logger.Sync.info "Process %d terminated." pid
;;
