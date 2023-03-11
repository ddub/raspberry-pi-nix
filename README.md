# raspberry-pi-nix

The primary goal of this flake is to make it easy to create
working NixOS configurations for Raspberry Pi products. Specifically,
this repository aims to deliver the following benefits:

1. Configure the kernel, device tree, and boot loader in a way that is
   compatible with the hardware and proprietary firmware.
2. Provide a nix interface to Raspberry Pi/device tree configuration
   that will be familiar to those who have used Raspberry Pi's
   [config.txt based
   configuration](https://www.raspberrypi.com/documentation/computers/config_txt.html).
3. Make it easy to build an image suitable for flashing to an sd-card,
   without the need to first go through an installation media.

The important modules are `overlay/default.nix`, `rpi/default.nix`,
and `rpi/config.nix`. The other modules are mostly wrappers that set
`config.txt` settings and enable required kernel modules.

## Example

```nix
{
  description = "raspberry-pi-nix example";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    raspberry-pi-nix.url = "github:tstat/raspberry-pi-nix";
  };

  outputs = { self, nixpkgs, raspberry-pi-nix }:
    let
      inherit (nixpkgs.lib) nixosSystem;
      basic-config = { pkgs, lib, ... }: {
        time.timeZone = "America/New_York";
        users.users.root.initialPassword = "root";
        networking = {
          hostName = "basic-example";
          useDHCP = false;
          interfaces = { wlan0.useDHCP = true; };
        };
        environment.systemPackages = with pkgs; [ bluez bluez-tools ];
        hardware = {
          bluetooth.enable = true;
          raspberry-pi = {
            config = {
              all = {
                base-dt-params = {
                  # enable autoprobing of bluetooth driver
                  # https://github.com/raspberrypi/linux/blob/c8c99191e1419062ac8b668956d19e788865912a/arch/arm/boot/dts/overlays/README#L222-L224
                  krnbt = {
                    enable = true;
                    value = "on";
                  };
                };
              };
            };
          };
        };
      };

    in {
      nixosConfigurations = {
        rpi-example = nixosSystem {
          system = "aarch64-linux";
          modules = [ raspberry-pi-nix.nixosModules.raspberry-pi basic-config ];
        };
      };
    };
}
```

## Building an sd-card image

An image suitable for flashing to an sd-card can be found at the
attribute `config.system.build.sdImage`. For example, if you wanted to
build an image for `rpi-example` in the above configuration
example you could run:

```
nix build '.#nixosConfigurations.rpi-example.config.system.build.sdImage'
```

## The firmware partition

The image produced by this package is partitioned in the same way as
the aarch64 installation media from nixpkgs: There is a firmware
partition that contains necessary firmware, u-boot, and
config.txt. Then there is another partition (labeled `NIXOS_SD`) that
contains everything else. The firmware and `config.txt` file are
managed by NixOS modules defined in this package. Additionally, NixOS
system activation will update the firmware and `config.txt` in the
firmware partition __in place__. Linux kernels are stored in the
`NIXOS_SD` partition and will be booted by u-boot in the firmware
partition.

## `config.txt` generation

As noted, the `config.txt` file is generated by the NixOS
configuration and automatically updated on system activation. 


## Firmware partition implementation notes

In Raspberry Pi devices the proprietary firmware manipulates the
device tree in a number of ways before handing it off to the kernel
(or in our case, to u-boot). The transformations that are performed
aren't documented so well (although I have found [this
list](https://forums.raspberrypi.com/viewtopic.php?t=329799#p1974233)
). 

This manipulation makes it difficult to use the device tree configured
directly by NixOS as the proprietary firmware's manipulation must be
known and reproduced.

Even if the manipulation were successfully reproduced, some benefits
would be lost. For example, the firmware can detect connected hardware
during boot and automatically configure the device tree accordingly
before passing it onto the kernel. If this firmware device tree is
ignored then a NixOS system rebuild with a different device tree would
be required when swapping connected hardware. Examples of what I mean
by hardware include: the specific Raspberry Pi device booting the
image, connected cameras, and connected displays.

So, in order to avoid the headaches associated with failing to
reproduce some firmware device tree manipulation, and to reap the
benefits afforded by the firmware device tree configuration, u-boot is
configured to use the device tree that it is given (i.e. the one that
the raspberry pi firmware loads and manipulates). As a consequence,
device tree configuration is controlled via the [config.txt
file](https://www.raspberrypi.com/documentation/computers/config_txt.html).

Additionally, the firmware, device trees, and overlays from the
`raspberrypifw` package populate the firmware partition on system
activation. This package is kept up to date by the overlay applied by
this package, so you don't need configure this. However, if you want
to use different firmware you can override that package to do so.

