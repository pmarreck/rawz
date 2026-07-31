{
  description = "rawz — cleanroom camera RAW parsing and validation in Zig with a C FFI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pname = "rawz";
        version = "0.1.0";
        zigPkg = pkgs.zig;

        # Fixed-output derivation for Zig deps (tiffz, once added).
        # To regenerate: set to pkgs.lib.fakeHash, `nix build`, use printed hash.
        zigDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        zigDeps = pkgs.stdenv.mkDerivation {
          pname = "${pname}-zig-deps";
          inherit version;
          src = ./.;
          nativeBuildInputs = [ zigPkg pkgs.git pkgs.cacert ];
          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = zigDepsHash;
          dontFixup = true;
          dontPatchShebangs = true;
          buildPhase = ''
            export HOME=$TMPDIR
            export ZIG_GLOBAL_CACHE_DIR=$out
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            zig build --fetch=all
          '';
          dontInstall = true;
        };

        # Only wire zigDeps in once build.zig.zon actually has dependencies;
        # an empty dep set makes the FOD hash meaningless (see the fleet's
        # "empty-tree FOD hash means the builder could not fetch" lesson).
        hasDeps = false;
        depSetup = pkgs.lib.optionalString hasDeps ''
          export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
          mkdir -p $ZIG_GLOBAL_CACHE_DIR
          cp -r ${zigDeps}/* $ZIG_GLOBAL_CACHE_DIR/
          chmod -R u+w $ZIG_GLOBAL_CACHE_DIR
        '';
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          inherit pname version;
          src = ./.;
          nativeBuildInputs = [ zigPkg ];
          dontConfigure = true;
          dontFixup = true;
          buildPhase = ''
            export HOME=$TMPDIR
            ${depSetup}
            ${pkgs.lib.optionalString pkgs.stdenv.isDarwin "unset NIX_CFLAGS_COMPILE NIX_LDFLAGS"}
            zig build -Doptimize=ReleaseFast --prefix $out
          '';
          dontInstall = true;
        };

        checks = {
          build = self.packages.${system}.default;
          test = pkgs.stdenv.mkDerivation {
            pname = "${pname}-test";
            inherit version;
            src = ./.;
            nativeBuildInputs = [ zigPkg ];
            dontConfigure = true;
            dontFixup = true;
            buildPhase = ''
              export HOME=$TMPDIR
              ${depSetup}
              ${pkgs.lib.optionalString pkgs.stdenv.isDarwin "unset NIX_CFLAGS_COMPILE NIX_LDFLAGS"}
              # FLEET FLOOR — tests run ReleaseSafe (fleet finding 2026-07-01,
              # adopted fleet-wide 2026-07-29). ReleaseFast compiles OUT the
              # runtime safety checks, so a green ReleaseFast suite cannot see
              # UB — it passes *because* the check that would have failed it is
              # gone. rarz was carrying three real crashers behind a green
              # ReleaseFast suite; tiffz hid a u32 underflow the same way.
              #
              # Set HERE, not as a per-module .optimize in build.zig: Zig
              # honours per-module optimize, so pinning only the test module
              # would leave imported library code at ReleaseFast.
              #
              # Shipped artifact and benchmarks stay ReleaseFast.
              timeout 600 zig build test -Doptimize=ReleaseSafe \
                || { echo "Tests failed"; exit 1; }
            '';
            installPhase = ''
              mkdir -p $out
              echo "tests passed" > $out/result
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [ zigPkg pkgs.hyperfine pkgs.jq pkgs.coreutils ];
        };
      });
}
