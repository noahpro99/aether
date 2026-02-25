{
  description = "A visual theming application for Omarchy";

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

          runtimeLibs = with pkgs; [
            glib
            gobject-introspection
            gtk4
            gtk4-layer-shell
            libadwaita
            libsoup_3
            gsettings-desktop-schemas
            adwaita-icon-theme
            glib-networking
          ];

          runtimeBins = with pkgs; [
            imagemagick
            swaybg
            hyprpaper
            procps # for pkill used in post-apply scripts
          ];

          desktopItem = pkgs.makeDesktopItem {
            name = "li.oever.aether";
            desktopName = "Aether";
            comment = "Visual theming application for Omarchy";
            exec = "aether";
            icon = "li.oever.aether";
            terminal = false;
            categories = [
              "GTK"
              "Settings"
              "DesktopSettings"
              "Utility"
            ];
            keywords = [
              "theme"
              "color"
              "omarchy"
              "wallpaper"
            ];
          };
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "aether";
            version = "unstable";
            src = ./.;

            nativeBuildInputs = [
              pkgs.makeWrapper
              pkgs.wrapGAppsHook3
            ];

            buildInputs = runtimeLibs ++ [ pkgs.gjs ];

            installPhase = ''
              runHook preInstall

              install -d $out/share/aether
              cp -r src templates $out/share/aether/
              cp README.md CLAUDE.md package.json package-lock.json $out/share/aether/

              install -Dm444 ${desktopItem}/share/applications/li.oever.aether.desktop \
                $out/share/applications/li.oever.aether.desktop

              install -Dm644 icon.png $out/share/icons/hicolor/256x256/apps/li.oever.aether.png

              makeWrapper ${pkgs.gjs}/bin/gjs $out/bin/aether \
                --add-flags "-m $out/share/aether/src/main.js"

              runHook postInstall
            '';

            postFixup = ''
              gappsWrapperArgs+=(--prefix PATH : ${lib.makeBinPath runtimeBins})
              gappsWrapperArgs+=(--prefix GI_TYPELIB_PATH : ${
                lib.makeSearchPath "lib/girepository-1.0" (runtimeLibs ++ [ pkgs.gjs ])
              })
              gappsWrapperArgs+=(--suffix XDG_DATA_DIRS : ${
                lib.makeSearchPath "share" (
                  runtimeLibs
                  ++ [
                    pkgs.gsettings-desktop-schemas
                    pkgs.adwaita-icon-theme
                  ]
                )
              })
              wrapGApp $out/bin/aether
            '';

            meta = {
              description = "Visual theming application for Omarchy environments";
              homepage = "https://github.com/bjarneo/aether";
              license = lib.licenses.mit;
              platforms = lib.platforms.linux;
            };
          };
        }
      );
    };
}
