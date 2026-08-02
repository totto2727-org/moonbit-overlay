# Main builder of moonPlatform.
#
# Reads moon.mod to determine metadata, dependencies, and the preferred build
# target so callers need minimal configuration:
#
#   pkgs.moonPlatform.buildMoonPackage {
#     src = ./.;
#     moonMod = ./moon.mod;
#     moonRegistryIndex = inputs.moon-registry;
#   }
{
  lib,
  stdenv,
  buildCachedRegistry,
  bundleWithRegistry,
  moonModToJson,
  ...
}:
let
  buildMoonPackage =
    {
      moonMod,
      moonRegistryIndex,
      moonFlags ? [ ],
      moonMainPkg ? null,
      moonTarget ? null,
      ...
    }@args:
    let
      parsedMoonMod = moonModToJson {
        inherit moonMod;
        registryIndexSrc = moonRegistryIndex;
      };

      # name is "owner/repo" in moon.mod; use the last component
      derivedName = lib.last (lib.splitString "/" (parsedMoonMod.name or "moon-package"));
      derivedVersion = parsedMoonMod.version or "0.0.0";
      preferredTarget = parsedMoonMod.preferred-target or "native";

      effectiveTarget = if moonTarget != null then moonTarget else preferredTarget;

      # Reverse-lookup: find a nixpkgs license by its SPDX identifier
      findLicenseBySpdxId =
        spdxId:
        let
          all = builtins.attrValues lib.licenses;
          matches = builtins.filter (l: (l.spdxId or "") == spdxId) all;
        in
        if matches != [ ] then builtins.head matches else null;

      derivedLicense =
        if parsedMoonMod ? license then findLicenseBySpdxId parsedMoonMod.license else null;
      derivedMeta =
        lib.optionalAttrs (parsedMoonMod ? description) { description = parsedMoonMod.description; }
        // lib.optionalAttrs (parsedMoonMod ? repository) { homepage = parsedMoonMod.repository; }
        // lib.optionalAttrs (derivedLicense != null) { license = derivedLicense; };

      cachedRegistry = buildCachedRegistry {
        moonModDepsSet = parsedMoonMod.deps or { };
        registryIndexSrc = moonRegistryIndex;
      };
      moonHome = bundleWithRegistry {
        inherit cachedRegistry;
      };
      nativeBuildInputs = lib.lists.unique ((args.nativeBuildInputs or [ ]) ++ [ moonHome ]);

      unpackPhase = ''
        mkdir -p $TMP
        cp -r $src/* $TMP
      '';

      buildPhase = ''
        cd $TMP

        # MOON_HOME from the nix store is read-only; moon needs to write
        # build caches and package metadata there, so create a writable copy.
        writable_home=$TMPDIR/moon_home
        cp -rL $MOON_HOME $writable_home
        chmod -R u+w $writable_home
        export MOON_HOME=$writable_home
        export HOME=$TMPDIR

        moon build \
          --target ${effectiveTarget} \
          --release \
          ${lib.concatStringsSep " " moonFlags}
      '';

      # Find and install all executable binaries produced by the build.
      installPhase = ''
        mkdir -p $out/bin
        find $TMP/_build/${effectiveTarget}/release/build/ \
          -name '*.exe' -type f -perm -0111 \
          -exec sh -c '
            for f; do
              base="$(basename "$f" .exe)"
              install -Dm755 "$f" "$out/bin/$base"
            done
          ' _ {} +
      '';

      checkPhase = ''
        cd $TMP
        moon test --target ${effectiveTarget}
      '';

      env = (args.env or { }) // {
        MOON_HOME = "${moonHome}";
      };
    in
    stdenv.mkDerivation (
      (builtins.removeAttrs args [
        "moonMod"
        "moonRegistryIndex"
        "moonFlags"
        "moonMainPkg"
        "moonTarget"
      ])
      // {
        name = args.name or derivedName;
        version = args.version or derivedVersion;
        doCheck = args.doCheck or true;
        inherit nativeBuildInputs env;
        meta = derivedMeta // (args.meta or { });
        unpackPhase = args.unpackPhase or unpackPhase;
        buildPhase = args.buildPhase or buildPhase;
        checkPhase = args.checkPhase or checkPhase;
        installPhase = args.installPhase or installPhase;
      }
    );
in
buildMoonPackage
