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
      guard reports.length() == 0 else {
        fail(reports.map(report => "\{report}").join("\n"))
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

        moon --target-dir "$TMPDIR/build" run \
          --target native \
          --release \
          --quiet \
          ${converter} < ${moonMod} > $out
      '';
in
builtins.fromJSON (builtins.readFile json)
