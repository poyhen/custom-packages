{
  lib,
  stdenvNoCC,
  fetchurl,
  appimageTools,
  makeWrapper,
  writeScript,
}:
let
  pname = "cursor";
  version = "0.41.3";
  appKey = "230313mzl4w4u92";
  src = appimageTools.extract {
    inherit pname version;
    src = fetchurl {
      url = "https://download.todesktop.com/230313mzl4w4u92/cursor-0.41.3-build-240925fkhcqg263-x86_64.AppImage";
      hash = "sha256-WtfyiNGnUn8g1HR0TQPyn3SMJmjqe+otAYeyokMIO+w=";
    };

    #workaround for https://github.com/getcursor/cursor/issues/837
    postExtract = ''
      substituteInPlace $out/resources/app/out/vs/code/electron-main/main.js \
        --replace ',minHeight' ',frame:false,minHeight'
    '';
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = appimageTools.wrapAppImage { inherit version pname src; };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/
    cp -r bin $out/bin

    mkdir -p $out/share/cursor
    cp -a ${src}/locales $out/share/cursor
    cp -a ${src}/resources $out/share/cursor
    cp -a ${src}/usr/share/icons $out/share/
    install -Dm 644 ${src}/cursor.desktop -t $out/share/applications/

    substituteInPlace $out/share/applications/cursor.desktop --replace-fail "AppRun" "cursor"

    wrapProgram $out/bin/cursor \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}} --no-update"

    runHook postInstall
  '';

  passthru.updateScript = writeScript "update.sh" ''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p curl yq coreutils gnused common-updater-scripts
    set -eu -o pipefail
    latestLinux="$(curl -s https://download.todesktop.com/${appKey}/latest-linux.yml)"
    version="$(echo "$latestLinux" | yq -r .version)"
    filename="$(echo "$latestLinux" | yq -r '.files[] | .url | select(. | endswith(".AppImage"))')"
    url="https://download.todesktop.com/${appKey}/$filename"
    currentVersion=$(nix-instantiate --eval -E "with import ./. {}; code-cursor.version or (lib.getVersion code-cursor)" | tr -d '"')

    if [[ "$version" != "$currentVersion" ]]; then
      hash=$(nix-hash --to-sri --type sha256 "$(nix-prefetch-url "$url")")
      update-source-version code-cursor "$version" "$hash" "$url" --source-key=src.src
    fi
  '';

  meta = {
    description = "AI-powered code editor built on vscode";
    homepage = "https://cursor.com";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ sarahec ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cursor";
  };
}
