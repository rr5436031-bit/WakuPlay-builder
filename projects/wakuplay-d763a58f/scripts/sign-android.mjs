import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import crypto from 'node:crypto'
import { execFileSync } from 'node:child_process'

const gradle = path.join('android', 'app', 'build.gradle')
if (!fs.existsSync(gradle)) { console.log('sign-android: android/app/build.gradle belum ada, dilewati'); process.exit(0) }

const dir = path.join(os.homedir(), '.wakuplay')
const jks = path.join(dir, 'wakuplay.jks')
const props = path.join(dir, 'sign.properties')
fs.mkdirSync(dir, { recursive: true })

if (!fs.existsSync(jks) || !fs.existsSync(props)) {
  const pass = crypto.randomBytes(12).toString('hex')
  const keytool = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, 'bin', 'keytool') : 'keytool'
  if (fs.existsSync(jks)) fs.rmSync(jks)
  execFileSync(keytool, ['-genkeypair', '-keystore', jks, '-alias', 'wakuplay', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000',
    '-storepass', pass, '-keypass', pass, '-dname', 'CN=WakuPlay, O=WakuPlay, C=ID'], { stdio: 'inherit' })
  fs.writeFileSync(props, `storeFile=${jks}\nstorePassword=${pass}\nkeyAlias=wakuplay\nkeyPassword=${pass}\n`, { mode: 0o600 })
  console.log('sign-android: kunci baru dibuat di ' + dir + '  (BACKUP folder ini!)')
} else console.log('sign-android: memakai kunci yang sudah ada di ' + dir)

let g = fs.readFileSync(gradle, 'utf8')
if (!g.includes('// wakuplay-sign')) {
  const head = `// wakuplay-sign\ndef wpProps = new Properties()\ndef wpFile = new File(System.getProperty("user.home"), ".wakuplay/sign.properties")\nif (wpFile.exists()) { wpFile.withInputStream { wpProps.load(it) } }\n\n`
  const cfg = `\n    signingConfigs {\n        wakuplay {\n            storeFile file(wpProps['storeFile'])\n            storePassword wpProps['storePassword']\n            keyAlias wpProps['keyAlias']\n            keyPassword wpProps['keyPassword']\n        }\n    }\n`
  if (!/\nandroid\s*\{/.test(g)) { console.error('sign-android: blok "android {" tidak ditemukan di build.gradle'); process.exit(1) }
  g = g.replace(/\nandroid\s*\{/, (m) => '\n' + head.trimEnd() + '\n' + m + cfg)
  g = g.replace(/(buildTypes\s*\{[\s\S]*?\brelease\s*\{)/, '$1\n            signingConfig signingConfigs.wakuplay')
  fs.writeFileSync(gradle, g)
  console.log('sign-android: build.gradle diperbarui (release memakai kunci WakuPlay)')
}
