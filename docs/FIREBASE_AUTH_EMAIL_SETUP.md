# Firebase Auth email setup for Munib

This checklist is the console-side companion to the Auth email UX implemented in the app and mini website.

## Current code behavior

- Email verification and password-reset messages are sent in the app's current language (`ar` or `en`) by setting the Firebase Auth language code immediately before sending.
- Firebase's single custom Auth action URL should point to the Munib router at `/auth-action`.
- `/auth-action` preserves Firebase query parameters and routes `verifyEmail` to `/verify-email` and `resetPassword` to `/reset-password`.
- The browser handlers work without the app installed and provide a button to open Munib when appropriate.

## One-time Firebase Console configuration

Do these steps only after Firebase Hosting is deployed successfully.

1. Open Firebase Console for project `munib-f5102`.
2. Go to **Authentication > Settings > Authorized domains**.
3. Confirm `munib-f5102.web.app` is authorized. Add it if it is missing.
4. Go to **Authentication > Templates**.
5. Set the public-facing app name to **Munib / مُنِيب** where Firebase exposes that setting.
6. Use **Customize action URL** and set the single handler URL to:

   `https://munib-f5102.web.app/auth-action`

7. Review the verification and password-reset sender name, reply-to address, and subjects. Keep Firebase's localized templates unless you intentionally maintain Arabic and English custom copy. Never remove the action link placeholder (`%LINK%`) from a customized template.
8. Send real test messages to at least Gmail and Outlook/Hotmail accounts and verify both Inbox and Spam/Junk behavior.

## Recommended template approach

Use Firebase's localized templates together with the app-selected language. This avoids forcing one bilingual subject/body on every user. Brand the sender/public-facing name as Munib and use the Munib action URL above.

If custom copy is introduced later, Firebase supports placeholders including `%DISPLAY_NAME%`, `%APP_NAME%`, `%LINK%`, and `%EMAIL%`. Keep wording short and transactional and do not include sensitive account information beyond what Firebase already provides for the action.

## Spam / deliverability

A custom domain can improve brand consistency, but it does **not** guarantee Inbox placement. If Munib later gets a custom domain, configure it through Firebase Authentication's **Customize domain** flow and add the DNS records Firebase provides. Maintain only one valid SPF record for the domain and verify all required DNS records before applying the domain.

In the app UI, keep the existing guidance to check Spam/Junk and allow controlled resend attempts. Do not repeatedly send messages automatically; repeated sends can hurt user experience and may trigger provider abuse protections.

## Production verification checklist

- Verification email arrives in Arabic when the app is Arabic.
- Verification email arrives in English when the app is English.
- Password-reset email follows the same locale behavior.
- Email action link opens `https://munib-f5102.web.app/auth-action?...`.
- `mode=verifyEmail` reaches `/verify-email` and successfully verifies a valid code.
- `mode=resetPassword` reaches `/reset-password` and successfully resets a valid code.
- Used and expired codes show a safe error state.
- No account-existence information leaks from forgot-password UI.
- Spam/Junk guidance is visible in the app.
