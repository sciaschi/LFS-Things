{
  description = "NixOS + Plasma starter (Flatpak, PipeWire, CRIU/DMTCP)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11"; # current stable
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  in {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Your main system config module (inline for convenience)
        ({ config, pkgs, ... }: {
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          # Boot & base
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          time.timeZone = "America/New_York";
          i18n.defaultLocale = "en_US.UTF-8";

          # KDE Plasma 6 on Wayland + SDDM
          services.xserver.enable = true;
          services.displayManager.sddm.enable = true;
          services.displayManager.sddm.wayland.enable = true;
          services.desktopManager.plasma6.enable = true;

          # Audio (PipeWire)
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
            jack.enable = true;
          };

          # Networking
          networking.networkmanager.enable = true;

          # Flatpak
          services.flatpak.enable = true;

          # Useful for device handoff experiments
          environment.systemPackages = with pkgs; [
            criu
            dmtcp
            flatpak
            git
            wget curl jq
            kdePackages.kate
            konsole
            firefox
            # add more here
          ];

          # KDE Connect (optional but handy across devices)
          programs.kdeconnect.enable = true;

          # Users (replace with your username)
          users.users.sean = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
            initialPassword = "changeme";
          };

          # Allow sudo for wheel
          security.sudo.enable = true;
          security.sudo.wheelNeedsPassword = true;

          # Unfree allowed globally (helps with codecs/firmware)
          nixpkgs.config.allowUnfree = true;

          # Firmware & OpenGL
          hardware.opengl.enable = true;
          hardware.enableRedistributableFirmware = true;

          # OPTIONAL: enable SSH to push/pull your flake between machines
          services.openssh.enable = true;
        })

        # Home Manager (optional starter; swap 'sean' for your user)
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.sean = { pkgs, ... }: {
            home.stateVersion = "24.11";
            programs.git.enable = true;
            # KDE settings can live here later if you want
          };
        }
      ];
    };
  };
}
