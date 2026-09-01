# Security Policy

Report security or privacy concerns privately to **theclimatenote@gmail.com**. Do not open a public
issue for a suspected vulnerability, exposed credential, private user data, or authentication flaw.

## Secrets

The following must never be committed:

- Vercel, Gemini, Firebase Admin, Google Drive, or other API secrets
- Apple certificates, provisioning profiles, private keys, or App Store Connect API keys
- `.env` files other than the documented `.env.example`
- exported production user data, database backups, logs containing tokens, or private reflections

If a credential is accidentally exposed, stop using it, notify a project administrator, rotate it at
the provider, and remove it from Git history before continuing development.

## Access

Grant teammates the least-powerful role needed for their work. Production deployment, Firebase
administration, and App Store submission access should remain limited to designated maintainers.
