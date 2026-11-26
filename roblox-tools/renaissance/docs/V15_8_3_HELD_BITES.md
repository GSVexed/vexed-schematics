# Renaissance 15.8.3: held native bites and measured cadence

**Hold to Repeat Bites** is on by default in Combat. Holding left mouse or R2 repeats the game's own `tryBite` action when its native cooldown and Rest/ability/capture checks allow it. Release stops scheduling immediately. It can be switched off separately from **Faster Bites**.

The latter is a reversible client Species cooldown adjustment. Version 15.8.2 used `min(original, max(original * .70, nativeHitDelay + .025, .08))`. Version 15.8.3 uses `min(original, max(original * .55, nativeHitDelay + .05, .08))`. The upper rate bounds from these factors are 1.43x and 1.82x normal respectively. The delayed-contact floor, passive multiplier, private native guards, target availability and server validation can lower accepted rates. The hub never injects a hit claim.

The repeat scheduler retains a physically held input across a temporary native ability, checks actual readiness before releasing recovery or attempting a bite, and pauses when `tryBite` produces no native `WolfBiteAt` marker. The Combat readout shows readiness and its current scheduler status.

Test Features records own-character native bite marker intervals for the current animal, excluding gaps over three seconds between encounters. The bounded report adds `biteCadence` with marker count, active interval count, mean/min/max spacing and measured markers per second. This is client-observed bite timing, not confirmed damage or server acceptance. The private runner accepts both 15.8.2 and 15.8.3 reports.

Local validation: 251/251 Renaissance scenarios and 263/263 integrated Territory scenarios passed. In-game acceptance of the new cadence remains to be observed.
