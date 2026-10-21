# Security policy

## Reporting a vulnerability

Please **do not** report security problems in public issues. Use GitHub's
[private vulnerability reporting](https://github.com/pinkmoneyx-bigguys/flux-torrent/security/advisories/new) instead.

It helps to include:

1. what kind of problem it is and which part of Flux it affects (the interface, the updater, the installer, streaming…);
2. the steps to reproduce it;
3. a proof of concept, if you have one;
4. what an attacker could do with it.

You will get an answer as soon as possible, and credit in the release notes if you would like it.

## Supported versions

Only the latest release gets security fixes — Flux updates itself, so staying current takes one click.

## The engine

Flux runs on the qBittorrent engine (libtorrent). A vulnerability in the engine itself is best reported to
[qBittorrent](https://github.com/qbittorrent/qBittorrent/security/policy) as well, so every client built on it gets the fix.
