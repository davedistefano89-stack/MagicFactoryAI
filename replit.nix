{pkgs}: {
  deps = [
    pkgs.xorg.libxshmfence
    pkgs.xorg.libXdamage
    pkgs.xorg.libXcomposite
    pkgs.xorg.libXinerama
    pkgs.xorg.libXcursor
    pkgs.xorg.libXfixes
    pkgs.xorg.libXrandr
    pkgs.glib
    pkgs.freetype
    pkgs.fontconfig
    pkgs.dbus
    pkgs.xorg.libxkbfile
    pkgs.libGL
    pkgs.mesa
    pkgs.xorg.libXtst
    pkgs.xorg.libXi
    pkgs.xorg.libXrender
    pkgs.xorg.libXext
    pkgs.xorg.libX11
    pkgs.xorg.libxcb
    pkgs.libxkbcommon
  ];
}
