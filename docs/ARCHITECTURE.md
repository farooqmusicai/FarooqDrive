# Architecture

## Windows

Flutter Windows UI → system browser OAuth with PKCE → temporary loopback
callback → Google Drive REST API. The operating system's secure credential
storage protects refresh tokens. No Client Secret is bundled in the app.

## Web

Static HTML/CSS/JavaScript → Google Identity Services token client → Google Drive
REST API. No FarooqDrive backend receives files or Google access tokens. The
public Web Client ID is stored as a browser preference; tokens live only in page
memory and disappear on reload.

## Repository safety boundary

Committed: source, icons, examples, build workflow, help, privacy template.
Never committed: OAuth secrets, tokens, databases, personal files, certificates,
real environment files, or signed Store packages.
