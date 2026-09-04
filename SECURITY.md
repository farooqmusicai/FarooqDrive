# Security policy

- Never commit OAuth client secrets, access tokens, refresh tokens, cookies,
  database files, signing certificates, or personal Google data.
- The web edition uses a public Web OAuth Client ID and keeps access tokens only
  in page memory. It never requests or stores a client secret.
- The Windows edition stores each user's Desktop OAuth configuration and account
  tokens locally using Electron safeStorage where supported.
- Report vulnerabilities privately to the project owner before public disclosure.
- Revoke a suspected token in Google Account > Security > Third-party access.
