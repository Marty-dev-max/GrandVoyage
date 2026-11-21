// 8-bit sounds with jsfxr (v0.25.6, owner). Presets: pickupCoin laserShoot explosion powerUp hitHurt jump blipSelect
//   node tools/sfx/gen_jsfxr.js <preset> <OutName>   -> assets/sfx/<OutName>.wav (then tools/upload_sfx.py --only OutName)
const fs = require('fs');
const path = require('path');
const { sfxr } = require('jsfxr');
const [preset, name] = process.argv.slice(2);
if (!preset || !name) {
  console.log('usage: node tools/sfx/gen_jsfxr.js <preset> <OutName>');
  process.exit(1);
}
const wave = sfxr.toWave(sfxr.generate(preset));
const out = path.join(__dirname, '..', '..', 'assets', 'sfx', name + '.wav');
fs.writeFileSync(out, Buffer.from(wave.dataURI.split(',')[1], 'base64'));
console.log('wrote', out);
