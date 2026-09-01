# Team operations

GitHub is the source of truth for code. Service access is managed separately so production secrets
and privileges do not travel with a clone of the repository.

## Access map

| Service | Default teammate access | Maintainer access |
| --- | --- | --- |
| GitHub | Write through feature branches and pull requests | Maintain/Admin |
| Vercel | Preview deployments and logs when needed | Production settings and environment variables |
| Firebase | Viewer or the narrow product role required | Firebase Admin/Owner only when necessary |
| App Store Connect | Developer | App Manager; Account Holder stays with the owner |
| Google Drive | Viewer or Editor on the approved article folder | Service-account and publishing configuration |

Never copy production secrets into GitHub. Add or rotate Vercel values in the Vercel dashboard, and
manage Firebase access in Project settings → Users and permissions.

## Web releases

1. Open a pull request against `main`.
2. Review the Vercel preview and automated checks.
3. Obtain one teammate approval.
4. Merge to `main`; Vercel deploys production.
5. Confirm the production deployment is healthy and record notable changes in the release notes.

## iOS releases

1. Update `MARKETING_VERSION` for a public version and increment `CURRENT_PROJECT_VERSION` for every
   uploaded build.
2. Build against production configuration and run simulator plus physical-device checks.
3. Archive in Xcode and validate before upload.
4. Test the exact uploaded build in TestFlight.
5. Update screenshots, privacy answers, age rating, review notes, and release text when behavior changes.
6. Submit through App Store Connect and tag the accepted source revision.

## Article publishing

Editors add approved DOCX files to the configured Google Drive folder. The scheduled ingestion job
validates and publishes one eligible document at a time. Investigate failed jobs in Vercel before
editing production data directly. Article imagery remains disabled for version 1.

## Joining and leaving

When someone joins, grant only the services required for their role and require two-factor
authentication. When someone leaves, remove GitHub, Vercel, Firebase, App Store Connect, and Drive
access promptly, then rotate any shared credential they could access.
