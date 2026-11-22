#!/usr/bin/env python3
"""Game sound effects from text prompts with ElevenLabs (v0.25.6, owner). The API key is injected by the session's
network proxy (header xi-api-key), so nothing is stored here.
   python3 tools/gen_sfx_elevenlabs.py [--only PunchHit,Coin]   -> assets/sfx/<Name>.wav
   ROBLOX_API_KEY=... python3 tools/upload_sfx.py --user 1527424396 --only PunchHit,Coin
Names match Config/Sounds entries; an entry with `prefer` keeps playing its Blk* sound unless the prefer is removed."""
import json, os, subprocess, sys, tempfile, urllib.request

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
API = 'https://api.elevenlabs.io/v1/sound-generation'

SFX = {
    # v0.25.33: Cursed Fruit appeared (Fruit Notifier), played with the narrator line
    'FruitTwinkle': ('a magical twinkling shimmer, bright glittering chime sparkle, mysterious, fantasy game, no voice', 1.6),
    # v0.25.16 (owner: sounds still felt the same): footsteps by ground + weightier impacts
    'StepGrass': ('a single footstep on soft grass, short soft rustle, game foley, no voice', 0.5),
    'StepWood': ('a single footstep on wooden planks of a pier, short hollow knock, game foley', 0.5),
    'StepSand': ('a single footstep on dry beach sand, short soft crunch, game foley', 0.5),
    'StepStone': ('a single footstep on a stone path, short crisp tap, game foley', 0.5),
    'ImpactThump': ('a deep low body impact thump, short bassy hit, fighting game, no voice', 0.5),
    'FinisherBoom': ('a huge finishing blow impact, bass boom with a shockwave whoosh, anime fighting game, no voice', 0.9),
    # combat (owner: satisfying, chunky, not shrill)
    'PunchHit': ('a solid punch hitting a body, short punchy impact, anime fighting game, no voice', 0.5),
    'PunchHeavy': ('a heavy finishing punch impact with a deep thud and a whoosh of air, anime fighting game, no voice', 0.8),
    'SliceHit': ('a quick sword slash cutting through cloth, sharp swish and hit, game sound effect', 0.5),
    'ShotHit': ('a slingshot pellet hitting a target, small thwack impact, game sound effect', 0.5),
    'Crit': ('a critical hit impact, punchy crack with a short bright shimmer, fighting game', 0.7),
    'Whoosh': ('a fast short whoosh of a dash, cartoon game sound effect', 0.5),
    'MonsterDie': ('a cartoon monster defeated, soft poof and blocks tumbling apart, cute game sound, low pitch', 0.9),
    'MobAlert': ('a short cartoon surprise exclamation sting, single bright note, game sound', 0.5),
    # rewards
    'Coin': ('a few gold coins clinking softly into a leather pouch, low warm tone, game UI', 0.6),
    'Pickup': ('picking up an item into a cloth bag, soft thump and rustle, game UI', 0.5),
    'LevelUp': ('a triumphant level up jingle, short bright magical chime rising, RPG game', 1.6),
    'ChestOpen': ('a wooden treasure chest creaking open with a sparkling magical shimmer, RPG game', 1.4),
    'CardDrop': ('a rare card drop reveal, magical sparkle swoosh, game sound effect', 1.0),
    'RefineSuccess': ('a blacksmith upgrade success, metal ring with a bright magical sparkle, RPG game', 1.0),
    'RefineFail': ('a blacksmith upgrade failure, dull metal clunk and a sad descending tone, game', 0.9),
    'Heal': ('a gentle healing spell, soft rising sparkles, RPG game', 0.9),
    # v0.25.54 (owner: rare drops / fruits sounded too shrill, wants an achievement-like tone; ship needs wood creaks)
    'RewardRare': ('a warm achievement unlocked sound, soft mellow bell chime with a gentle rising harp, low-mid pitch, cozy RPG game reward, not shrill, no voice', 1.8),
    'RewardLegend': ('a warm grand achievement unlocked fanfare, soft brass swell with mellow bells and a shimmer, triumphant but gentle, low-mid pitch, RPG game, not shrill, no voice', 2.6),
    'ShipCreakLoop': ('a wooden sailing ship hull creaking and groaning at sea, slow rhythmic wood creaks, ropes straining, timbers rubbing, no water splash, no music, seamless', 6.0),
    # v0.25.59 (owner: the fruit sonar sounded choppy): a clean looping sonar for the Fruit Notifier beacon
    'FruitSonarLoop': ('a deep calm submarine sonar ping repeating every two seconds, each ping with a long soft echo tail, underwater, clean, no music, no voice, seamless', 8.0),
    # sea
    'Cannon': ('a pirate ship cannon firing, deep boom with a wooden echo', 1.2),
    'Explosion': ('a cannonball explosion on wood, punchy blast with debris', 1.2),
    'ShipHit': ('a cannonball smashing into a wooden ship hull, splintering crunch', 1.0),
}


def gen(name, prompt, dur):
    body = json.dumps({'text': prompt, 'duration_seconds': dur, 'prompt_influence': 0.6}).encode()
    req = urllib.request.Request(API, data=body, method='POST', headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=120) as r:
        mp3 = r.read()
    with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as f:
        f.write(mp3)
        src = f.name
    out = os.path.join(OUT, name + '.wav')
    # mono 44.1 kHz, trim leading silence, normalize loudness a little below full scale
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-ac', '1', '-ar', '44100',
                    '-af', 'silenceremove=start_periods=1:start_threshold=-50dB,loudnorm=I=-16:TP=-2', out], check=True)
    os.remove(src)
    return out


def main():
    only = set(sys.argv[sys.argv.index('--only') + 1].split(',')) if '--only' in sys.argv else None
    for name, (prompt, dur) in SFX.items():
        if only and name not in only:
            continue
        try:
            print('OK  ', name, gen(name, prompt, dur))
        except Exception as e:  # keep going: one bad prompt must not stop the batch
            print('FAIL', name, e)


if __name__ == '__main__':
    main()
