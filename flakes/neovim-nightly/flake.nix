{
  description = "Flake that packages Neovim nightly for macOS ARM64";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system}.neovim-nightly = pkgs.neovim-unwrapped.overrideDerivation
		(oldAttrs: {
			version = "nightly-2025-12-21";
			src = pkgs.fetchFromGitHub {
				owner = "neovim";
				repo = "neovim";
				tag = "nightly";
				hash = "sha256-FLTN6GQZaQfddZBwOOcTxK90PNGtAjsx+FBvU/LxtUk=";
			};
			doInstallCheck = false;
		});
    defaultPackage.${system} = self.packages.${system}.neovim-nightly;
  };
}

			#    pname = "neovim-nightly";
			#    version = "2025-12-21"; # update as needed
			#
			#    src = fetchTarball {
			#      url = "https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-arm64.tar.gz";
			#      sha256 = "0c6r4cbahkndpilg4a1qc9yfngaa8wlfan1kpppsgn2py4swrkb3"; # replace with actual hash
			#    };
			#
			#    installPhase = ''
			#      mkdir -p $out/
			#      cp -r $src/* $out/
			#    '';
			#
			# inherit lua;
			#
			#    meta = with pkgs.lib; {
			#      description = "Neovim nightly build for macOS ARM64";
			#      homepage = "https://neovim.io/";
			#      license = licenses.asl20;
			#      platforms = [ "aarch64-darwin" ];
			#      maintainers = with maintainers; [ ];
			#      teams = with teams; [ ];
			#      mainProgram = "nvim";
			#    };
			#  };

    # pname = "neovim-unwrapped";
    # version = "0.11.5";
    #
    # __structuredAttrs = true;
    #
    # src = fetchFromGitHub {
    #   owner = "neovim";
    #   repo = "neovim";
    #   tag = "v${finalAttrs.version}";
    #   hash = "sha256-OsvLB9kynCbQ8PDQ2VQ+L56iy7pZ0ZP69J2cEG8Ad8A=";
    # };
