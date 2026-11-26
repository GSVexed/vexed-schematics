# 16.1.2 — hold ownership continuation candidate

This follows the tested 16.1.1 candidate. The user reports that holding primary mouse attack sometimes produces two bites and then stops.

## Source-level findings
- The processed-input handler ignored synthetic InputBegan only while the input API call was synchronously active. Virtual-input APIs can enqueue the input and deliver it after the call returns; a processed echo then cancelled the real M1 and left inputSuspended latched until a new press.
- The scheduler cleared the originating physical hold whenever the cursor merely hovered over the hub, although only a new click on an actual hub control should revoke it.

## Changes
- Ignore primary mouse InputBegan during a short, specifically owned synthetic pulse/grace interval, regardless of whether the injected event is processed. The existing no-replay path still cancels genuinely consumed clicks.
- Pause while the pointer is over the hub without discarding an already valid world-originating hold; native InputEnded and direct UI presses still cancel it.
- Add delayed processed-echo, hover/resume and real-consumed-click regressions.

These correct code-level cancellation paths. They do not establish live executor event provenance, sustained accepted damage or server permission for more attacks. Native cooldowns, ability locks, minigame priority and the existing timed backoff remain intact.

## Validation
Run the official Luau/CI regressions and deterministic release gate before publishing a loader. Keep 16.1.1 and the 15.7 stable loader immutable.
