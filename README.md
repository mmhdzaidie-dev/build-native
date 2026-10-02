# ZEIA Native Android iOS

ZEIA is a native Flutter music app for Android and iOS.

## Supabase

The app now supports Supabase Auth with email and password, Postgres data, Storage for playlist covers, and Realtime synchronization. Email verification uses Supabase Auth OTP. The app accepts 6 to 8 digit verification codes and verifies email signup codes with the current email OTP flow.

Database features include profiles, playlists, playlist songs, liked songs, recently played, cross-device sync, and realtime playlist/library updates. Audio streaming remains external; Supabase stores song metadata and user relationships.

Run `supabase/schema.sql` once in the Supabase SQL Editor.

Create these GitHub Actions repository secrets:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

The app uses the Supabase publishable key on the client. Do not put a service-role or secret key in the mobile app.

For local builds, pass:

`flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY`

Supabase email/password authentication follows Supabase Auth. If Confirm email is enabled, new accounts must confirm their email before a session is issued. For the Confirm signup template, include `{{ .Token }}` in the email body so Supabase sends the verification code. Current Supabase email template documentation describes the token as an 8-digit OTP.


## Social profile

ZEIA v16 adds native profile and social features backed by Supabase: liked songs live inside the profile, editable display name and bio, avatar upload, followers, following, follow and unfollow, profile search, follower/following lists, and realtime refresh for profile and follow changes.

Run `supabase/schema.sql` in the Supabase SQL Editor before using social features. The schema creates the `profiles` and `follows` tables, RLS policies, realtime publication entries, and the `avatars` storage bucket.

## Telegram build notifications

GitHub Actions can notify the owner after every Android and iOS build.

Create these additional GitHub Actions repository secrets:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

The workflow sends one success message when both builds finish successfully. If Android or iOS fails, it sends a failure message and attaches `logs.txt` containing the captured build output. The GitHub Actions run remains failed so the red status is still visible in GitHub.

The Telegram bot must have an active chat with the owner first. Open the bot in Telegram and send `/start` once.

Never commit the Telegram bot token to the repository or put it in Dart source code. Store it in GitHub Actions secrets as `TELEGRAM_BOT_TOKEN`.


Build notification: GitHub Actions automatically sends Telegram success/error notifications to the configured owner. On failure, the complete combined build output is assembled as logs.txt and sent as a Telegram document.
