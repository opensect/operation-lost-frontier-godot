# SOLID + modular design

- **Single Responsibility:** one class per concern. Player (input
  coordination), PlayerMovement (physics only), PlayerHealth (health only),
  WeaponController (weapons only), Enemy (AI), Boss (phases), MissionManager
  (mission state only), LevelBuilder (level construction only), LanManager
  (session only), LanDiscovery (UDP beacons only), Hud / MainMenu /
  TouchControls (one screen each), SaveManager (persistence only),
  AudioManager (audio API only). Main.gd is a thin coordinator.
- **Open/Closed:** new weapons, enemies and bosses are new entries in
  GameData / new WeaponResource data - no gameplay class is edited to add
  one. Boss extends Enemy instead of editing Enemy.
- **Liskov Substitution:** Boss IS an Enemy - same take_damage / die /
  group contract, usable anywhere an Enemy is used (spawning, combat,
  mission kill counting). RemotePlayer and Player both answer
  apply_damage / heal through the same small API.
- **Interface Segregation:** modules talk through small signals and a
  small public API per class (e.g. WeaponController: fired / reloaded /
  weapon_changed / ammo_changed) - no class must implement one huge
  interface.
- **Dependency Inversion:** dependencies are injected via setup(game,
  character, ...) and signals, never hard-coded concrete classes.
  LevelBuilder receives the layout dictionary and the Game; Combat is a
  stateless service over scene-tree groups. Data (GameData) is separate
  from behaviour everywhere.
- **Modular folders:** player/, weapons/, enemies/, missions/, lan/, ui/,
  world/, save/, audio/, core/ - each module is independently readable,
  reusable across missions, and a new weapon/enemy/mission can be added
  without touching other modules.
