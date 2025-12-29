# AArch64 Testing Setup (Cross-Compile + QEMU)

These steps set up an AArch64 toolchain and QEMU user-mode emulator for
assembling and optionally running AArch64 binaries.

## Install toolchain + QEMU (Debian/Ubuntu)

```bash
sudo apt-get install gcc-aarch64-linux-gnu qemu-user
```

## Configure CompCert for AArch64

```bash
./configure -toolprefix aarch64-linux-gnu- aarch64-linux
make ccomp
```

## Assemble a CompCert-generated test

```bash
./ccomp -S runtime/test/test_int64.c
aarch64-linux-gnu-as -o /tmp/t.o runtime/test/test_int64.s
```

## Run under QEMU (optional)

```bash
aarch64-linux-gnu-gcc -static -o /tmp/t runtime/test/test_int64.s
qemu-aarch64 -L /usr/aarch64-linux-gnu /tmp/t
```
