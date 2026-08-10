{
  buildCachedRegistry,
  bundleWithRegistry,
  runCommand,
  stdenv,
  writeText,
}:
{
  moonMod,
  registryIndexSrc,
}:
let
  converterDeps = {
    "moonbitlang/async" = "0.20.1";
    "moonbitlang/moon_config" = "0.3.8";
  };
  cachedRegistry = buildCachedRegistry {
    inherit registryIndexSrc;
    moonModDepsSet = converterDeps;
  };
  moonHome = bundleWithRegistry {
    inherit cachedRegistry;
  };
  converter = writeText "moon-mod-json.mbtx" ''
    ///|
    import {
      "moonbitlang/moon_config@0.3.8",
      "moonbitlang/async@0.20.1",
      "moonbitlang/async@0.20.1/stdio",
    }

    ///|
    async fn main {
      let source = @stdio.stdin.read_all().text()
      let (ast, reports) = @moon_config.parse_moon_mod(source, name="<stdin>")
      // source is valid in moon.mod but is not recognized by moon_config 0.3.8.
      let actionable_reports = reports.filter(report =>
        report.msg != "Invalid moon.mod config: unexpected key `source`."
      )
      guard actionable_reports.length() == 0 else {
        fail(actionable_reports.map(report => "\{report}").join("\n"))
      }
      println(ast.to_json().stringify(indent=2))
    }
  '';
  json =
    runCommand "moon-mod.json"
      {
        nativeBuildInputs = [
          moonHome
          stdenv.cc
        ];
      }
      ''
        writable_home=$TMPDIR/moon_home
        cp -rL ${moonHome} "$writable_home"
        chmod -R u+w "$writable_home"
        export MOON_HOME="$writable_home"
        export HOME=$TMPDIR

        writable_converter=$TMPDIR/moon-mod-json.mbtx
        cp ${converter} "$writable_converter"

        converter_output=$TMPDIR/moon-mod.json
        if ! "$writable_home/bin/.moon-wrapped" --target-dir "$TMPDIR/build" run \
          --target native \
          --release \
          --quiet \
          "$writable_converter" < ${moonMod} > "$converter_output"; then
          cat "$converter_output" >&2
          exit 1
        fi
        install -Dm644 "$converter_output" $out
      '';
in
builtins.fromJSON (builtins.readFile json)
