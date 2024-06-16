let extract_regex_from_pipe read_end pattern =
  let in_channel = Unix.in_channel_of_descr read_end in
  let output = really_input_string in_channel (in_channel_length in_channel) in
  close_in in_channel;
  let regex = Str.regexp pattern in
  try if Str.search_forward regex output 0 > 0 then Some (Str.matched_string output) else None with
  | Not_found -> None
;;

let ensure_file_exists path =
  if not (Sys.file_exists path)
  then (
    let _ = open_out path in
    Unix.close (Unix.openfile path [ Unix.O_WRONLY ] 0o666))
;;
