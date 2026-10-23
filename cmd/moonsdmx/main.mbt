///|
fn read_input(path : String) -> String raise {
  let text = @fs.read_file_to_string(path)
  if text.length() > 16777216 {
    raise @sdmx.Limit(resource="CLI text", maximum=16777216)
  }
  text
}

///|
fn usage() -> Unit {
  println(
    "Append --output NEW_PATH for exact UTF-8 file output (existing paths refused).",
  )
  println("moonsdmx json2csv [--drop-annotations] MESSAGE.json")
  println("moonsdmx extract-structure MESSAGE.json")
  println("moonsdmx validate-csv STRUCTURE.json DATA.csv")
  println(
    "moonsdmx csv2json STRUCTURE.json DATA.csv MESSAGE_ID SENDER PREPARED_UTC",
  )
}

///|
fn run(original : Array[String]) -> Unit raise {
  let size = original.length()
  let destination = if size >= 4 && original[size - 2] == "--output" {
    Some(original[size - 1])
  } else {
    None
  }
  let args = if destination is Some(_) {
    original[:size - 2].to_owned()
  } else {
    original
  }
  if destination is Some(path) && @fs.path_exists(path) {
    raise @sdmx.Conflict(key=path, reason="output already exists")
  }
  if args.length() < 2 {
    usage()
    @sys.exit(2)
    return
  }
  let output = match args[1] {
    "json2csv" if args.length() == 3 =>
      @sdmx.decode_json2(read_input(args[2])).encode_csv2()
    "json2csv" if args.length() == 4 && args[2] == "--drop-annotations" =>
      @sdmx.decode_json2(read_input(args[3]))
      .without_annotations()
      .encode_csv2()
    "reencode-json2" if args.length() == 6 =>
      @sdmx.decode_json2(read_input(args[2])).encode_json2(
        id=args[3],
        sender=args[4],
        prepared=args[5],
      )
    "extract-structure" if args.length() == 3 =>
      @sdmx.decode_json2(read_input(args[2]))
      .dataset()
      .structure()
      .to_profile_json()
    "validate-csv" if args.length() == 4 => {
      let structure = @sdmx.Structure::from_profile_json(read_input(args[2]))
      let message = @sdmx.decode_csv2(structure, read_input(args[3]))
      "valid Information message: \{message.dataset().length()} observations; source=\{message.reference().format()}"
    }
    "csv2json" if args.length() == 7 => {
      let structure = @sdmx.Structure::from_profile_json(read_input(args[2]))
      @sdmx.decode_csv2(structure, read_input(args[3])).encode_json2(
        id=args[4],
        sender=args[5],
        prepared=args[6],
      )
    }
    _ => {
      usage()
      @sys.exit(2)
      return
    }
  }
  // Exact file output avoids Windows console text-mode newline translation.
  match destination {
    Some(path) => @fs.write_string_to_file(path, output)
    None => {
      let display = output.replace_all(old="\r\n", new="\n")
      println(
        if display.has_suffix("\n") {
          display[:display.length() - 1].to_owned()
        } else {
          display
        },
      )
    }
  }
}

///|
fn main {
  run(@env.args()) catch {
    @sdmx.Invalid(path~, reason~) => {
      println("ERROR: \{path}: \{reason}")
      @sys.exit(1)
    }
    @sdmx.Limit(resource~, maximum~) => {
      println("ERROR: \{resource}: limit \{maximum} exceeded")
      @sys.exit(1)
    }
    @sdmx.Unsupported(feature~) => {
      println("ERROR: unsupported profile: \{feature}")
      @sys.exit(1)
    }
    @sdmx.Conflict(key~, reason~) => {
      println("ERROR: \{key}: \{reason}")
      @sys.exit(1)
    }
    error => {
      println("ERROR: \{error.to_string()}")
      @sys.exit(1)
    }
  }
}
