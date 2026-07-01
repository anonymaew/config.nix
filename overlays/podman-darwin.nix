final: prev: {
  podman =
    if prev.stdenv.hostPlatform.isDarwin
    then
      prev.stdenv.mkDerivation rec {
        pname = "podman";
        version = "6.0.0";

        src = prev.fetchzip {
          url = "https://github.com/podman-container-tools/podman/releases/download/v${version}/podman-remote-release-darwin_${
            if prev.stdenv.hostPlatform.system == "x86_64-darwin"
            then "amd64"
            else "arm64"
          }.zip";
          sha256 = "0s5fvbqzszx6pazc6nn7wrycb1qisqh2p9vyq499frq8mqfm3zi5";
        };

        installPhase = ''
          mkdir -p $out/bin $out/share/man/man1
          cp usr/bin/podman $out/bin/podman
          cp usr/bin/podman-mac-helper $out/bin/podman-mac-helper
          cp docs/*.1 $out/share/man/man1/
          chmod +x $out/bin/*
        '';

        meta = with prev.lib; {
          homepage = "https://podman.io/";
          description = "Program for managing pods, containers and container images";
          longDescription = ''
            Podman (the POD MANager) is a tool for managing containers and images,
            volumes mounted into those containers, and pods made from groups of
            containers. This is the macOS binary distribution.
          '';
          license = licenses.asl20;
          platforms = ["aarch64-darwin" "x86_64-darwin"];
          mainProgram = "podman";
        };
      }
    else prev.podman;
}
