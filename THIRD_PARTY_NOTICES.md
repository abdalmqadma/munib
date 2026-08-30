# Third-party notices

## Adhan audio

Munib can cache selected Adhan recordings at runtime from the public `Kiwifu/adhan-mp3` repository. The repository describes the collection as free for Islamic apps, prayer-time software, and personal use.

Sources currently used by the Android Adhan player:

- Madinah: `Adhan_Al_Haram_Al_Madani_-_Al_Madinah_1_(أذان_الحرم_المدني_-_المدينة_المنورة).mp3`
- Makkah: `Ali_Ibn_Ahmad_Mala_1_-_Al_Haram_Al_Maki_(علي_بن_أحمد_ملا_-_الحرم_المكي).mp3`
- Source repository: `https://github.com/Kiwifu/adhan-mp3`

The audio files are not bundled into the application repository. They are downloaded over HTTPS only after the feature is configured, validated against an allowlist and size limit, and stored in the app-private files directory for offline playback.
