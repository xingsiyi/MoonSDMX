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
  println(
    "moonsdmx registry-dsd STRUCTURE_MESSAGE.json DSD_REF [EXTERNAL_MESSAGE.json]",
  )
  println("moonsdmx inspect-bundle DATA_MESSAGE.json [STRUCTURE_MESSAGE.json]")
  println("moonsdmx validate-registry-csv STRUCTURE_MESSAGE.json DATA.csv")
  println("moonsdmx provider-json1 INPUT.json FLOW_REF ID SENDER PREPARED_UTC")
  println("moonsdmx inspect-provider-json1 INPUT.json FLOW_REF")
  println("moonsdmx validate-csv STRUCTURE.json DATA.csv")
  println(
    "moonsdmx csv2json STRUCTURE.json DATA.csv MESSAGE_ID SENDER PREPARED_UTC",
  )
}

///|
fn bundle_summary(bundle : @sdmx.ExchangeBundle) -> String {
  let items : Array[Json] = bundle
    .datasets()
    .map(item => {
      let m = item.message()
      let (valid_from, valid_to) = item.validity()
      {
        "action": item.action().format(),
        "kind": m.kind().format(),
        "source": m.reference().format(),
        "validationStructure": m.dataset().structure().reference().format(),
        "validFrom": match valid_from {
          Some(v) => Json::string(v)
          None => Json::null()
        },
        "validTo": match valid_to {
          Some(v) => Json::string(v)
          None => Json::null()
        },
        "rows": m
        .dataset()
        .observations()
        .map(row => {
          let value : Json = {
            "key": row.key(),
            "measures": row
            .measures()
            .map(v => {
              match v {
                Some(s) => Json::string(s)
                None => Json::null()
              }
            }),
            "attributes": row
            .attributes()
            .map(v => {
              match v {
                Some(s) => Json::string(s)
                None => Json::null()
              }
            }),
          }
          value
        }),
      }
    })
  Json::array(items).stringify()
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
    "registry-dsd" if args.length() == 4 || args.length() == 5 => {
      let external = if args.length() == 5 {
        [@sdmx.StructureCatalog::from_json2(read_input(args[4]))]
      } else {
        []
      }
      @sdmx.StructureCatalog::from_json2(read_input(args[2]), external~)
      .resolve(Datastructure, @sdmx.StructureRef::parse(args[3]))
      .to_profile_json()
    }
    "inspect-bundle" if args.length() == 3 || args.length() == 4 => {
      let catalog = if args.length() == 4 {
        Some(@sdmx.StructureCatalog::from_json2(read_input(args[3])))
      } else {
        None
      }
      bundle_summary(@sdmx.decode_json2_bundle(read_input(args[2]), catalog~))
    }
    "reencode-bundle" if args.length() == 6 =>
      @sdmx.decode_json2_bundle(read_input(args[2])).encode_json2(
        id=args[3],
        sender=args[4],
        prepared=args[5],
      )
    "validate-registry-csv" if args.length() == 4 =>
      bundle_summary(
        @sdmx.decode_csv2_bundle(
          read_input(args[3]),
          @sdmx.StructureCatalog::from_json2(read_input(args[2])),
        ),
      )
    "provider-json1" if args.length() == 7 =>
      @sdmx.decode_json1_provider(
        read_input(args[2]),
        @sdmx.StructureRef::parse(args[3]),
      ).encode_json2(id=args[4], sender=args[5], prepared=args[6])
    "inspect-provider-json1" if args.length() == 4 =>
      bundle_summary(
        @sdmx.decode_json1_provider(
          read_input(args[2]),
          @sdmx.StructureRef::parse(args[3]),
        ),
      )
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
