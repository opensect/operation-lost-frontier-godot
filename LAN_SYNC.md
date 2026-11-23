# LAN Sync — Operation: Lost Frontier (Godot)

How 1–4 players stay in sync over LAN, and what was tested.

## Transport

- **Game:** Godot `ENetMultiplayerPeer` (UDP) on port **7777**, max 4 players.
  Host: `create_server(7777, 4)`. Client: `create_client(ip, 7777)`.
- **Discovery:** UDP broadcast on port **8888**. The host broadcasts
  `LOSTFRONTIER:7777` once a second; a client listening on 8888 learns
  the host's IP and shows it in the lobby (`FIND HOST`). Join by IP is
  also available (type the host's IP, `JOIN`).
- **Permissions (Android):** `INTERNET`, `ACCESS_NETWORK_STATE`,
  `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`.

## Authority model (host-authoritative)

| Thing | Owner | Why |
|---|---|---|
| Own player's position / HP / ammo | Each peer (its own player) | Input is local; the host never overrides your position |
| Enemy HP, boss HP | Host | One source of truth; clients report hits, host applies them |
| Pickups (claimed or not) | Host | Validates every claim before it counts |
| Objectives, mission number | Host | Clients follow the host's mission |
| Remote players' position / HP | The remote peer (sent in its state) | Each peer reports itself |

## Messages

- **Player state** — 20 Hz (`STATE_INTERVAL = 0.05`), unreliable.
  `{pos, hp, downed, facing, mag, reserve}` — about 7 small values.
  Sent by every peer about its own player (`Player.sync_state()`).
- **Host snapshot** — 10 Hz (`SNAPSHOT_INTERVAL = 0.1`), unreliable.
  `{seq, mission, enemies: [[home_x, home_y, x, y, hp]...],
  boss: [hp, max_hp], claims: [keys...], objectives: [done...]}`.
  Sent by the host; an immediate snapshot is sent when a peer joins.
- **Damage report** — reliable RPC (`_rpc_damage`). A client hit on an
  enemy/boss is NOT applied locally; it is sent to the host, which
  validates it (enemy exists at that spawn point, amount 1–500) and
  applies it. The result comes back in the next snapshot. Shield-Trooper
  frontal block and boss core-exposed double damage are evaluated on
  the host, so every peer sees the same result.
- **Pickup claim** — reliable RPC (`_rpc_pickup`). The host validates:
  the pickup is a real spawn, it is not already claimed, and the
  claimant is within 500 px of it (`PICKUP_CLAIM_MAX_DIST`). Only then
  is the claim applied and broadcast. Claim keys are the pickup's
  **spawn position** (`Pickup.spawn_pos`) — never its live bobbed
  position, which drifts with time and would differ per peer.

## Prediction / reconciliation

- **Local player — client-side prediction.** Input is applied
  immediately; the host never overrides the local player's position.
- **Remote players — interpolation.** `RemotePlayer` lerps toward the
  last received position at 12/s, so movement is smooth even at 20 Hz.
- **Enemies / boss / pickups / objectives — snapshot reconciliation.**
  On each snapshot the client matches enemies by spawn point (home):
  if drift is over 96 px (`SNAP_DIST`) it snaps, otherwise it lerps
  halfway. Host-killed enemies are removed; claimed pickups are freed;
  objectives are replaced with the host's list. A snapshot with an
  empty enemy list is ignored (the host is mid-load).
- **Deterministic spawns.** Before the enemy spawn loop,
  `load_mission_level()` seeds the RNG with
  `seed(current_mission * 7919 + 13)`, so every peer picks the SAME
  enemy types at the same spawn points. Without this no snapshot could
  ever make the peers agree.

## Lag, jitter, packet loss

- State and snapshots are **unreliable** (UDP) — a lost packet is simply
  replaced by the next one 50–100 ms later; nothing blocks on it.
- Every snapshot carries a sequence number. **Stale or duplicate
  snapshots are dropped** (out-of-order UDP), so a late packet can never
  rewind the game.
- Damage and pickup claims are **reliable** RPCs, so they are never lost
  — but they are also validated on the host, so a duplicated or forged
  claim is harmless.
- All sends are gated on the link being up
  (`_is_link_up()`: `get_connection_status() == CONNECTED`), so a
  client that is still handshaking never spams "peer not connected"
  errors.

## Physics sync

- Movement runs on Godot's fixed physics tick (60 Hz) in
  `PlayerMovement.physics_step()` (called from `Player._physics_process`),
  with coyote time, jump buffering, variable jump height, and
  acceleration/deceleration. The same fixed step runs on every peer, so
  the same inputs produce the same motion.
- Enemies and bosses also run on the physics tick and are gated on
  `game.paused` / `game.started`, so a paused or pre-start peer does not
  drift ahead.

## Testing

- `tools/lan_sync_test.gd` + `tools/run_lan_sync_test.sh` (run:
  `bash tools/run_lan_sync_test.sh 6`). Headless, in-process, sequential
  phases: the host plays alone (collects a pickup), is frozen, then the
  client plays alone (routes a damage claim to the host), then the host
  snapshot is applied to the client and everything is compared.
  Asserts: enemies agree (positions ≤ 150 px, HP equal, including the
  routed damage), claims agree, objectives agree, the RemotePlayer
  interpolates to the host (≤ 150 px, HP matches), and a re-applied
  snapshot is dropped as stale. **Result: PASS.**
- **Sandbox limit (not a game bug):** this sandbox blocks UDP sends at
  the syscall level (Python `sendto()` on 127.0.0.1 → `PermissionError:
  [Errno 1] Operation not permitted`). Two Godot processes can therefore
  never complete an ENet handshake here (both `create_server` and
  `create_client` return OK, but the client gets `connection_failed` and
  ENet logs "Sending failed!"). The protocol above is fully tested
  in-process; the UDP wire itself is stock Godot ENet and still needs
  a real two-device test on hardware.
