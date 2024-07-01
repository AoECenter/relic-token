let read_pipe_to_string pipe =
  let buffer = Buffer.create 4096 in
  let bytes = Bytes.create 4096 in
  let rec read_loop () =
    let len = Unix.read pipe bytes 0 4096 in
    if len > 0
    then (
      Buffer.add_subbytes buffer bytes 0 len;
      read_loop ())
  in
  read_loop ();
  Buffer.contents buffer
;;

let ensure_file_exists path =
  if not (Sys.file_exists path)
  then (
    let _ = open_out path in
    Logger.Sync.info ~m:"Io" ~f:"ensure_file_exists" "Creating missing file '%s'" path;
    Unix.close (Unix.openfile path [ Unix.O_WRONLY ] 0o666))
;;

let rec resolve_symlink path =
  Logger.Sync.debug ~m:"Io" ~f:"resolve_symlink" "Resolving symlink '%s'" path;
  if Sys.file_exists path
  then
    if Sys.is_directory path
    then path
    else (
      try
        let link_target = Unix.readlink path in
        let dir = Filename.dirname path in
        let abs_link_target =
          if Filename.is_relative link_target then Filename.concat dir link_target else link_target
        in
        resolve_symlink abs_link_target
      with
      | Unix.Unix_error (EINVAL, _, _) -> path
      | e -> raise e)
  else failwith ("Path does not exist: " ^ path)
;;
