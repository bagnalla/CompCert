# PowerPC Testing Setup (Cross-Compile + QEMU)

These steps set up a PowerPC toolchain and QEMU user-mode emulator for
assembling and optionally running PPC binaries.

## Install toolchain + QEMU (Debian/Ubuntu)

```bash
sudo apt-get install gcc-powerpc-linux-gnu qemu-user
```

## Configure CompCert for PowerPC

```bash
./configure -toolprefix powerpc-linux-gnu- ppc-linux
make ccomp
```

## Assemble a CompCert-generated test

```bash
./ccomp -S -falign-cond-branches 32 -falign-branch-targets 256 \
  tests/powerpc/branch-relax-align.c
powerpc-linux-gnu-as -o /tmp/t.o tests/powerpc/branch-relax-align.s
```

## Run under QEMU (optional)

```bash
powerpc-linux-gnu-gcc -static -o /tmp/t tests/powerpc/branch-relax-align.s
qemu-ppc -L /usr/powerpc-linux-gnu /tmp/t
```
