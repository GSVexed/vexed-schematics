# FERAL Renaissance 16.1.3 — Independent Left Alt hold trigger

## Why change methods

User reports that the 16.1.2 M1 repeat continues to fail in live gameplay. Repeated synthetic M1 up/down events can change the same mouse state used to detect a human hold. Source-level fixes for delayed input echo, pointer movement and M1 ownership have not established live success.

## Different method

With **Combat → Hold to Repeat Bites** ON, **hold Left Alt instead of left-click**. The hub now tracks the independent physical keyboard key via `UserInputService:IsKeyDown` and InputBegan/InputEnded. It invokes the game's validated native `WolfController.tryBite` callback when available. If the private callback is inaccessible, it retains the existing native-input fallback without requiring M1 to be physically held; the fallback cannot unset the Alt key.

- The normal left mouse button continues to work normally; ordinary M1 repeat remains as an existing, unverified path.
- Does not send undocumented Bite/BiteHit remotes, forge hit replies, or override native cooldown/ability/rest rules.
- Releases the hold on physical Left Alt release or focus/character/menu changes; known minigames have priority, preserving automation.
- During a hunter minigame, overlapping native bites are permitted only if an original validated callback exists and the existing separate minigame ownership checks pass.
- Alt is not a guaranteed unused key in every FERAL build; check for native conflicting bindings in live gameplay.

## Validation expectations

Four additional service-boundary cases cover independent key hold, delayed M1 echoes, prey minigame priority and feature disabled. The earlier 424 Renaissance and 305 Territory cases must also pass.

No local test or CI run proves that the Roblox server accepts multiple attacks or that the selected executor supports the native callback or synthetic mouse input. This release must remain a reviewable candidate until tested in live play.
