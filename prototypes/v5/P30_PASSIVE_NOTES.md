# P30 passive melon prototype — tested alternative, not final V5

E139 constructed the module only from these exact decoded schematic bytes in the isolated Minecraft Java 26.2 engine. Format 7; DataVersion 4903; SHA-256 `1abfab0d105b7f6e2ed263c4c0be69390a2595cf9281f1a28a4c0e6d5e06554d`.

| Acceptance | Measured result |
|---|---|
| Bounding box | 16×16×16, one horizontally aligned chunk |
| Hardware | 1,804 non-air blocks; 132 stems; 36 hoppers; two moving hopper carts |
| Initial/ongoing bonemeal supply | Zero / zero |
| Sustained game hour | +149 bonemeal / 72,002 GT after 24-minute warm-up |
| Normal 20-TPS sample | +16 bonemeal / real 300.009 seconds, 6,000 GT |
| Collection | Both carts visited every one of 22 crop rows |
| Mechanical health | 132 mature/attached stems, 132 hydrated farmland, all 308 exact rail shapes and all eight water sources survived |
| Recovery | Actual lever OFF, saved restart, witnessed true unload, OFF reload, RUN and resumed export passed |
| Congestion | Full internal/external output stops harvesting; drain only external output and harvesting resumes |

Natural growth requires a nearby player. Mature stems are included for creative startup; survival requires planting and maturation. No steady fertiliser input is needed. The module owns local composting, surplus buffer, lever and export hoppers; attach external storage at local [1,0,16] to the south-facing boundary hopper [1,0,15]. Shared shulkers/storage/sell wall are separate and unfinished.

E139 used **strict rail placement** so adjacent curves retained their file shapes. Ordinary sequential command placement rerouted the failed P29. Native client Litematica import/paste, practical survival rail assembly and zero-Motion cart restart remain unverified; cart Motion is included. The project's full quality target and live Donut compatibility are unproven.

[Readable E139 result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/139-passive-p30.json) · [Full inventory result, gzip](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/139-passive-p30.full.json.gz) · [Windows run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38249096042) · [Original builder](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_module_p30_builder.py).

Single-player Litematica can preserve block and entity data and prevent placement updates, according to its [maintainer's paste documentation](https://github.com/maruohon/litematica/wiki/Schematic-Pasting). This supports a possible acceptance path; it is not evidence that this prototype was pasted through that client.
