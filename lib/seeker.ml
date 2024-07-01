type t =
  | Found of string
  | NotFound of string
  | Error of string

let rec seek fd pattern buffer =
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
    then seek fd pattern buffer
    else (
      let lines = String.split_on_char '\n' contents in
      let regex = Str.regexp pattern in
      let rec check_lines = function
        | [] ->
          Logger.Sync.debug "Seek reached end of buffer";
          NotFound ""
        | line :: rest -> if Str.string_match regex line 0 then Found line else check_lines rest
      in
      match check_lines lines with
      | Found line as found ->
        Logger.Sync.debug "Line match for '%s' on line '%s'" line pattern;
        found
      | NotFound partial ->
        Buffer.clear buffer;
        Buffer.add_string buffer partial;
        seek fd pattern buffer
      | _ -> seek fd pattern buffer)
  | exception e ->
    Logger.Sync.error "Error while seeking: %s" (Printexc.to_string e);
    Error (Printexc.to_string e)
;;
