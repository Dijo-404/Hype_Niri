# Bounded sudo PTY teardown flush

`sudo-1.9.17p2-bounded-pty-flush.patch` is a local patch against the unmodified sudo 1.9.17p2 release source. It addresses the reproduced hang after a command exits while its terminal stops consuming output. The historical 100% CPU spin after closing the terminal remains unconfirmed.

The patch keeps relay descriptors nonblocking during final flushing, checks a two-second monotonic deadline between event passes, and stops flushing on pending HUP, INT, QUIT, TERM, ALRM, USR1, or USR2 signals. Incomplete passes sleep for 10 ms, so an unwritable terminal does not cause continuous polling. Existing signal handlers remain registered on their original event base. Suspension and non-PTY flushing retain their existing behavior.

Ordinary output and command exit status are preserved. Output still queued after the deadline or an interruption is discarded so cleanup can continue. This bounds the relay flush; a blocking I/O plugin or a device-specific terminal restoration operation is outside that bound. The patch has not been installed into the system sudo package. The deployed Stealth `!use_pty` workaround remains active.

Apply to a copy of a configured sudo 1.9.17p2 source tree:

```bash
patch --fuzz=0 -p1 < /path/to/Hype_Niri/patches/sudo/sudo-1.9.17p2-bounded-pty-flush.patch
make -j4
make check -j4
```

For a scratch build whose configuration belongs to your user, run the upstream checks in a mapped user namespace so ownership checks see that user as root:

```bash
unshare --map-root-user --map-auto --mount --pid --fork --mount-proc --kill-child=KILL make check -j4
```

Prior validation used a temporary Linux PTY regression harness in isolated unprivileged user, mount, and PID namespaces with private devpts. Scratch-built binaries read isolated `sudo.conf`/`sudoers` files with `use_pty` and root-to-root command authorization. The harness did not authenticate through or edit the host's sudo configuration.

The validation covered complete 128 KiB output, delayed reading of an 80 KiB tail, a full terminal, stopped output (`TCOOFF`), SIGINT/SIGTERM/SIGHUP during final flushing, and terminal closure. Unmodified binaries reproduced the blocked-output hang; patched binaries completed blocked flushes within three seconds and signal interruptions within 0.8 seconds. Both versions preserved ordinary output and exit status 37.

Verified on Arch Linux on 2026-10-06: the patch applies to the clean release without fuzz, the build succeeds, all eight PTY cases pass, and the full configured upstream test suite passes in a user namespace. Blocked and stopped output returned approximately 2.01 seconds after command completion; termination signals released the flush in approximately 5 ms. Baseline blocked-output and signal cases remained hung until test cleanup. The scratch build disables PAM; live PAM session closure has not been tested.
