{
  description = "Aether - a visual theming application (Wails + Svelte)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
          lib = pkgs.lib;

          version = "3.0.0";

          # Native libs the Wails/WebKitGTK runtime links against.
          guiLibs = with pkgs; [
            webkitgtk_4_1
            gtk3
            glib
            cairo
            pango
            gdk-pixbuf
            harfbuzz
            librsvg

            # GIO TLS backend. WebKitGTK loads remote images (Wallhaven thumbnails)
            # in its own network process, and without this module every https
            # fetch fails and the webview renders a broken-image icon.
            # wrapGAppsHook3 only adds it to GIO_EXTRA_MODULES if it is an input.
            glib-networking

            # Fallback icon theme, so missing-icon lookups do not render blank.
            adwaita-icon-theme
          ];

          # Binaries aether shells out to at runtime (internal/platform).
          # It calls: bash, sh, hyprctl, omarchy, update-desktop-database.
          # omarchy is intentionally absent - it is optional and aether
          # feature-detects it with exec.LookPath.
          runtimeBins = with pkgs; [
            bash
            coreutils
            hyprland # provides hyprctl
            desktop-file-utils # provides update-desktop-database
          ];

          # The Svelte frontend, built separately and embedded into the Go
          # binary via //go:embed all:frontend/dist in main.go.
          frontend = pkgs.buildNpmPackage {
            pname = "aether-frontend";
            inherit version;
            src = ./frontend;

            npmDepsHash = "sha256-5c4xSQaZQX/KQV28jKo2MnCRze10IEAnfr1Sg+o3V0s=";

            # vite build -> ./dist
            installPhase = ''
              runHook preInstall
              cp -r dist $out
              runHook postInstall
            '';
          };
        in
        {
          inherit frontend;

          default = pkgs.buildGoModule {
            pname = "aether";
            inherit version;
            src = ./.;

            vendorHash = "sha256-i8Tr4zKm+LaaZ/zKA8yoZC5mv2s4DUqaeT7Iq0uB+ME=";

            subPackages = [ "." ];

            nativeBuildInputs = with pkgs; [
              pkg-config
              wrapGAppsHook3
              copyDesktopItems
            ];

            buildInputs = guiLibs;

            # wails build injects desktop,production itself; a plain go build must
            # pass them or wails.Run aborts with "will not build without the
            # correct build tags". webkit2_41 is the same switch the Makefile
            # makes when pkg-config cannot find webkit2gtk-4.0.
            tags = [
              "desktop"
              "production"
              "webkit2_41"
            ];

            # main.go embeds frontend/dist, which is gitignored and therefore
            # absent from src. Drop the prebuilt frontend in before compiling.
            preBuild = ''
              rm -rf frontend/dist
              cp -r ${frontend} frontend/dist
              chmod -R u+w frontend/dist
            '';

            # cli.Version is deliberately left at its "dev" default. Stamping a
            # real version would enable `aether upgrade`, which downloads a
            # release binary and overwrites itself - meaningless against an
            # immutable Nix store. Left as-is, that command refuses with a clear
            # message and upgrades happen through `nix flake update` instead.
            ldflags = [
              "-s"
              "-w"
            ];

            desktopItems = [
              (pkgs.makeDesktopItem {
                name = "li.oever.aether";
                desktopName = "Aether";
                comment = "Desktop theming application";
                exec = "aether";
                icon = "aether";
                terminal = false;
                startupNotify = true;
                categories = [
                  "GTK"
                  "Settings"
                  "DesktopSettings"
                  "Utility"
                ];
                keywords = [
                  "theme"
                  "color"
                  "hyprland"
                  "waybar"
                  "customization"
                  "desktop"
                  "palette"
                  "omarchy"
                ];
              })
              (pkgs.makeDesktopItem {
                name = "li.oever.aether.url-handler";
                desktopName = "Aether URL Handler";
                comment = "Apply themes, colors, and wallpapers from aether:// web links";
                exec = "aether --handle-url %u";
                icon = "aether";
                terminal = false;
                noDisplay = true;
                startupNotify = false;
                mimeTypes = [ "x-scheme-handler/aether" ];
                categories = [ "Utility" ];
                keywords = [
                  "theme"
                  "color"
                  "wallpaper"
                  "import"
                ];
              })
            ];

            postInstall = ''
              install -Dm644 assets/aether-icon-512.png \
                $out/share/icons/hicolor/512x512/apps/aether.png
            '';

            # Append the runtime PATH to the gapps wrapper rather than adding a
            # second makeWrapper layer, which wrapGAppsHook3 would clobber.
            preFixup = ''
              gappsWrapperArgs+=(--suffix PATH : ${lib.makeBinPath runtimeBins})
            '';

            # Test suites reach the network / a real desktop; the Makefile's
            # `make test` target is the supported entry point instead.
            doCheck = false;

            meta = {
              description = "Desktop theming application - extract palettes from wallpapers and apply cohesive themes";
              homepage = "https://github.com/bjarneo/aether";
              license = lib.licenses.mit;
              platforms = lib.platforms.linux;
              mainProgram = "aether";
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              go
              nodejs
              wails
              pkg-config
              webkitgtk_4_1
              gtk3
            ];
          };
        }
      );
    };
}
