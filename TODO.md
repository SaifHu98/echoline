# TODO

Release delivery gates only:

- Revoke the previously exposed GitHub token immediately, then approve and execute a coordinated Git history purge/force-push so Gitleaks can scan the complete repository history cleanly.
- Provide protected Android release keystore, alias, and passwords to CI.
- Run signed release APK/AAB install smoke on a physical or emulator device.
