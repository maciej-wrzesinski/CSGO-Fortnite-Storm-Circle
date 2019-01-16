# Fortnite Storm Circle for SourceMod
This plugin is the "Storm Circle" feature from Fortnite game, written in SourceMod. It creates a circle that slowly gets smaller. Every player who walks out of the circle will be damaged. 

# Changelog
```
1.0.1
- 'Fixed' float number display so it has only 2 digits after decimal

1.0
- Official version release
- Added more cvars
- Added 'sm_forcesc' command
- Storm Circle now appears on every round start
- Some code cleaning occured

0.3
- More cvars, steady particles, damage when outside

0.2
- Added cvars, logic, basic visuals

0.1
- Start of the project
```

# Cvars
```
fsc_start 0.0-infinity - After how many seconds since round start does the Storm Circle triggers? (0.0 = never)
fsc_shrink_duration 0.1-infinity - How many seconds of shrinking does it take for Storm Circle until it stands?
fsc_shrink_amount 0.1-infinity - How many in-game units the Storm Circle shrinks per one tick?
fsc_stand_duration 2.0-infinity - After how many seconds does the Storm Circle shrinks again?
fsc_damage 0.0-infinity - How much damage should Storm Circle deal per one tick? (0.0 = instant death)
fsc_tickrate 0.1-10.0 - How often does the Storm Circle updates its visuals and deals damage? (small values recomended)
fsc_color "50 50 255 200" - What color is the Storm Circle? (R G B A)
fsc_randomcenter 0-1 - Is the center of Storm Circle random? (0 = center of the map)
```
