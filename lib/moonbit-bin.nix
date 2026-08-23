{
  lib,
  pkgs,
  versions,
  minVersion,
}:

let
  inherit (pkgs) callPackage;

  inherit (callPackage ./utils.nix { })
    mkToolChainsUri
    target
    escape
    mkCoreUri
    releaseRepositoryFor
    ;

  mk =
    ref: record:
    let
      version = record.version;
      escapedRef = escape ref;
      releaseRepository = releaseRepositoryFor record;
      warnObsolete = lib.warnOnInstantiate "moonbit-bin: version `${version}` is obsolete, please upgrade to at least ${minVersion}" pkgs.emptyFile;
    in
    if
      (
        !(builtins.elem version [
          "latest"
          "updating"
          "nightly"
        ])
        && lib.versionOlder (lib.removePrefix "v" version) minVersion
      )
    then
      {
        moon-patched.${escapedRef} = warnObsolete;
        toolchains.${escapedRef} = warnObsolete;
        core.${escapedRef} = warnObsolete;
        moonbit.${escapedRef} = warnObsolete;
      }
    else
      rec {
        toolchains.${escapedRef} = callPackage ./toolchains.nix {
          inherit version;
          url = mkToolChainsUri version releaseRepository;
          hash = record."${target}-toolchainsHash";
        };
        core.${escapedRef} = callPackage ./core.nix {
          inherit version;
          url = mkCoreUri version releaseRepository;
          hash = record.coreHash;
        };

        moonbit.${escapedRef} = callPackage ./bundle.nix {
          toolchains = toolchains."${escapedRef}";
          core = core."${escapedRef}";
        };
      };

  flattenAttrs = lib.foldl' (
    acc: item:
    acc
    // (builtins.listToAttrs (
      builtins.concatMap (
        pkgType:
        let
          pkgVersions = item.${pkgType};
        in
        lib.mapAttrsToList (ver: val: {
          name = "${pkgType}_${ver}";
          value = val;
        }) pkgVersions
      ) (builtins.attrNames item)
    ))
  ) { };

  availableVersions = lib.filterAttrs (
    _: record: target != "linux-aarch64" || builtins.hasAttr "${target}-toolchainsHash" record
  ) versions;
  versionPkgs = builtins.attrValues (lib.mapAttrs mk availableVersions);
in
{
  packages = flattenAttrs versionPkgs;
  legacyPackages = builtins.foldl' lib.recursiveUpdate { } versionPkgs;
}
