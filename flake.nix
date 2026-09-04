{
  description = "Ruby GTK4 development shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ pkg-config wrapGAppsHook4 ];
          buildInputs = with pkgs; [
            ruby_3_4
            bundler
            bundix
            gtk4
            libadwaita
            gobject-introspection
            glib
            cairo
            pango
            gdk-pixbuf
            harfbuzz
            libyaml
            openssl
            # glib2/gtk4 gem builds read glib's and gdk's .pc Requires.private,
            # so these transitive .pc files must be on PKG_CONFIG_PATH too.
            libsysprof-capture
            pcre2
            libffi
            util-linux
            zlib
            libselinux
            libxdmcp
            libXau
            libepoxy
            fribidi
            libthai
            libdatrie
            libxkbcommon
            wayland
            libpng
            expat
            at-spi2-core
            graphene
            librsvg
            libxml2
            libsepol
            # libportal: the background/autostart request and the OpenURI portal.
            libportal
            libportal-gtk4
          ];

          shellHook = ''
            export BUNDLE_PATH="$PWD/vendor/bundle"
            export BUNDLE_BUILD__GTK4="--use-system-libraries"
            export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0:${pkgs.libportal}/lib/girepository-1.0:${pkgs.libportal-gtk4}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
          '';
        };
      }
    );
}
