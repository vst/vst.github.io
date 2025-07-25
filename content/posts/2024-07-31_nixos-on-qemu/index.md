---
title: Running NixOS Guests on QEMU
date: 2024-07-31 14:41:19
description: A quick reference to create and run NixOS guests on QEMU.
slug: nixos-on-qemu
tags:
  - Technical Notes
  - NixOS
  - Computing
---

Once in a while, I want to test some NixOS configuration without affecting my
main system or launching new hosts on the cloud.

Running NixOS on a virtual machine (VM) is a safe and reproducible way to test
such configurations. As for VMs, I have used [VirtualBox], [Vagrant] and [lxd]
in the past. However, I have found QEMU to be the simplest and most flexible
solution for my needs.

This guide is a quick reference to create and run NixOS guests on QEMU.

<!--more-->

<!-- toc -->

For further information, you may refer to the [Official NixOS Manual] and
[nix.dev] tutorial "[NixOS Virtual Machines]".

## Creating Virtual Machine

First, we start with a relatively simple configuration:

```nix
## file: ./configuration.nix
{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall.allowedTCPPorts = [ 22 80 ];

  users.users.root = {
    initialPassword = "hebele-hubele";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJIQtEmoHu44pUDwX5GEw20JLmfZaI+xVXin74GI396z"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdd2ubdTn5LPsN0zaxylrpkQTW+1Vr/uWQaEQXoGkd3"
    ];
  };

  services.openssh.enable = true;

  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      default = true;
      locations."/" = {
        return = "200 'Hello World!'";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
  ];

  system.stateVersion = "24.05";
}
```

Note that I have used my own SSH public keys in the configuration. You should
use your own keys.

Then, given above `./configuration.nix` file, we can create a virtual machine
with the following command:

```sh
nix-build '<nixpkgs/nixos>' -A vm -I nixpkgs=channel:nixos-24.05 -I nixos-config=./configuration.nix
```

The built artifact can be found in the `result` symlink.

## Launching Virtual Machine

We want to use our terminal to interact with the virtual machine. Therefore, we
will use the `-nographic` option to disable the graphical interface and use
`ttyS0` as our console.

Furthermore, we want to be able to connect to the virtual machine via SSH. We
will use the `-net` option to forward the host port `2222` to the guest port
`22`. Likewise, we will forward the host port `24680` to the guest port `80` to
access the web server running on the virtual machine.

Finally, we will use the `run-nixos-vm` script to launch the virtual machine:

```sh
export QEMU_KERNEL_PARAMS="console=ttyS0"
export QEMU_NET_OPTS="hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:24680-:80"
./result/bin/run-nixos-vm -nographic; reset
```

We can login to the `root` account. We can also _SSH_ into the virtual machine:

```sh
ssh -p 2222 root@127.0.0.1 hostname
```

... or access the web server running on the virtual machine:

```sh
curl -D - http://localhost:24680
```

## Stopping Virtual Machine

If you are logged in to the root account, you can issue `poweroff` command to
stop the virtual machine.

Alternatively, you can kill the `qemu` process.

Finally, if you want to remove the state persisted by the virtual machine, you
can delete the `nixos.qcow2` file generated by the `run-nixos-vm` script.

<!-- REFERENCES -->

[NixOS Virtual Machines]:
  https://nix.dev/tutorials/nixos/nixos-configuration-on-vm
[Official NixOS Manual]: https://nixos.org/manual/nixos/stable/
[Vagrant]: https://www.vagrantup.com
[VirtualBox]: https://www.virtualbox.org
[lxd]: https://canonical.com/lxd
[nix.dev]: https://nix.dev
