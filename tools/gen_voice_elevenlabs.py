#!/usr/bin/env python3
"""Narrator voice lines with ElevenLabs text-to-speech (v0.25.33, owner: Fruit Notifier speaks). The API key is
injected by the session's network proxy (header xi-api-key), nothing is stored here.
   python3 tools/gen_voice_elevenlabs.py [--only Narr_FruitConchBay]   -> assets/sfx/<Name>.wav
   ROBLOX_API_KEY=... python3 tools/upload_sfx.py --user 1527424396 --only <names>
Lines: one per island (Config/Islands ids) so the voice can say where a Cursed Fruit appeared, never which fruit."""
import json, os, subprocess, sys, tempfile, urllib.request

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
VOICE = 'JBFqnCBsd6RMkjVDRZzb'  # George: warm British storyteller
API = f'https://api.elevenlabs.io/v1/text-to-speech/{VOICE}?output_format=mp3_44100_128'
ISLANDS = {
    'Daybreak': 'Daybreak Island', 'ConchBay': 'Conch Bay', 'Marmalade': 'Marmalade Town', 'Honeyslope': 'Honeyslope Village',
    'Barracuda': 'Barracuda Bistro', 'Mikan': 'the Mikan Isles', 'Epilogue': 'Epilogue Town', 'FortWest': 'Fort Driftwood',
    'FortMid': 'Fort Tidebreak', 'FortEast': 'Fort Gullwatch',
}
LINES = {f'Narr_Fruit{k}': f'A Cursed Fruit has appeared... on {v}.' for k, v in ISLANDS.items()}


def gen(name, text):
    body = json.dumps({'text': text, 'model_id': 'eleven_multilingual_v2',
                       'voice_settings': {'stability': 0.55, 'similarity_boost': 0.8, 'style': 0.35}}).encode()
    req = urllib.request.Request(API, data=body, method='POST', headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=120) as r:
        mp3 = r.read()
    with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as f:
        f.write(mp3)
        src = f.name
    out = os.path.join(OUT, name + '.wav')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-ac', '1', '-ar', '44100',
                    '-af', 'silenceremove=start_periods=1:start_threshold=-50dB,loudnorm=I=-16:TP=-2', out], check=True)
    os.remove(src)
    return out


def main():
    only = set(sys.argv[sys.argv.index('--only') + 1].split(',')) if '--only' in sys.argv else None
    for name, text in LINES.items():
        if only and name not in only:
            continue
        try:
            print('OK  ', name, gen(name, text))
        except Exception as e:  # keep going
            print('FAIL', name, e)


if __name__ == '__main__':
    main()
