```ps
New-Item -ItemType Directory -Force "$env:USERPROFILE\Documents\YenmaKeys"

& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -genkeypair `
  -v `
  -keystore "$env:USERPROFILE\Documents\YenmaKeys\yenma-upload.jks" `
  -alias yenma-upload `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000
```