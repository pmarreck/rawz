{
  description = "rawz — cleanroom camera RAW parsing and validation in Zig with a C FFI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Private transitive dependency (rawz -> tiffz -> jpegz -> libjxlz).
    # Nix fetches it through the caller's SSH credentials, then seeds Zig's
    # cache. The revision must match jpegz's build.zig.zon pin.
    libjxlz-src = {
      url = "git+ssh://git@github.com/pmarreck/libjxlz?ref=yolo&rev=93b29e86281ea4ba9c681f4879318c87e8a800a4";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, libjxlz-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pname = "rawz";
        version = "0.1.0";
        zigPkg = pkgs.zig;
        isDarwin = pkgs.stdenv.isDarwin;
        isLinux = pkgs.stdenv.isLinux;
        forbiddenCodecRequisites = [
          pkgs.zlib
          pkgs.openjpeg
          pkgs.libjpeg
          pkgs.libjxl
          pkgs.zstd
          pkgs.lerc
        ];

        # Fixed-output derivation for the Zig dependency graph rooted at tiffz.
        # To regenerate: set to pkgs.lib.fakeHash, `nix build`, use printed hash.
        zigDepsHash = "sha256-YyJ1HjrESTTJ9ZvEcOSEcvibWhOtPyd3JV1RlIQF4x4=";
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
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
            mkdir -p $ZIG_GLOBAL_CACHE_DIR
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            zig fetch ${libjxlz-src}
            zig build --fetch=all
            bash ./scripts/check-libjxlz-seed $ZIG_GLOBAL_CACHE_DIR/p ${libjxlz-src.rev}
          '';
          installPhase = ''
            mkdir -p $out
            cp -r $ZIG_GLOBAL_CACHE_DIR/p $out/p
          '';
        };

        depSetup = ''
          export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
          mkdir -p $ZIG_GLOBAL_CACHE_DIR
          cp -r ${zigDeps}/* $ZIG_GLOBAL_CACHE_DIR/
          chmod -R u+w $ZIG_GLOBAL_CACHE_DIR
        '';
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          inherit pname version;
          src = ./.;
          nativeBuildInputs = [ zigPkg pkgs.file ]
            ++ pkgs.lib.optionals isLinux [ pkgs.binutils ]
            ++ pkgs.lib.optionals isDarwin [ pkgs.darwin.cctools ];
          # Keep build-tool source paths out of release artifacts, then reject
          # codec references both directly and anywhere in the runtime closure.
          disallowedReferences = [ zigPkg ] ++ forbiddenCodecRequisites;
          disallowedRequisites = forbiddenCodecRequisites;
          dontConfigure = true;
          buildPhase = ''
            export HOME=$TMPDIR
            ${depSetup}
            ${pkgs.lib.optionalString isDarwin "unset NIX_CFLAGS_COMPILE NIX_LDFLAGS"}
            if ! zig build --verbose -Doptimize=ReleaseFast --prefix $out \
              > zig-build.log 2>&1; then
              cat zig-build.log
              exit 1
            fi
            ${pkgs.bash}/bin/bash tests/production_closure_test \
              $out/bin/rawz zig-build.log
          '';
          dontInstall = true;
        };

        checks = {
          build = self.packages.${system}.default;
          production-closure = self.packages.${system}.default;
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
              ${pkgs.lib.optionalString isDarwin "unset NIX_CFLAGS_COMPILE NIX_LDFLAGS"}
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
