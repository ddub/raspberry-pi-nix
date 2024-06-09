{
  description = "raspberry-pi nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/9a9960b98418f8c385f52de3b09a63f9c561427a";
    u-boot-src = {
      flake = false;
      url = "https://ftp.denx.de/pub/u-boot/u-boot-2024.04.tar.bz2";
    };
    rpi-linux-6_6-src = {
      flake = false;
      url = "github:raspberrypi/linux/stable_20240423";
    };
    rpi-firmware-src = {
      flake = false;
      url = "github:raspberrypi/firmware/1.20240424";
    };
    rpi-firmware-nonfree-src = {
      flake = false;
      url = "github:RPi-Distro/firmware-nonfree/88aa085bfa1a4650e1ccd88896f8343c22a24055";
    };
    rpi-bluez-firmware-src = {
      flake = false;
      url = "github:RPi-Distro/bluez-firmware/d9d4741caba7314d6500f588b1eaa5ab387a4ff5";
    };
    libpisp-src = {
      flake = false;
      url = "github:raspberrypi/libpisp/v1.0.5";
    };
  };

  outputs = srcs@{ self, ... }:
    let
      pinned = import srcs.nixpkgs {
        system = "aarch64-linux";
        overlays = with self.overlays; [ core ];
      };
    in
    {
      overlays = {
        core = import ./overlays (builtins.removeAttrs srcs [ "self" ]);
      };
      nixosModules.raspberry-pi = import ./rpi {
        inherit pinned;
        core-overlay = self.overlays.core;
      };
      packages.aarch64-linux = {
        linux = pinned.rpi-kernels.latest.kernel;
      };
    };
}
