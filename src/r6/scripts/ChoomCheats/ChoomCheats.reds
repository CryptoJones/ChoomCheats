// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Aaron K. Clark
//
// ChoomCheats: four toggleable single-player cheats for Cyberpunk 2077,
// written in pure redscript so they work on the native macOS build.
//
//   ChoomToggleGod       infinite health (engine god mode + health refill)
//   ChoomToggleMoney     infinite money (eddies kept at or above a floor)
//   ChoomToggleInvisible invisible to NPCs
//   ChoomToggleCarry     unlimited carry weight
//
// The action names above are bound to keys by scripts/install.sh.

module ChoomCheats

// ---------------------------------------------------------------------------
// Settings. Edit, then run scripts/install.sh again.
// ---------------------------------------------------------------------------
public abstract class ChoomConfig {
  // Eddies are topped back up to this amount while infinite money is on.
  public static func MoneyFloor() -> Int32 = 1000000
  // Carry capacity added while unlimited carry is on.
  public static func CarryBonus() -> Float = 100000.0
  // How often (seconds) the active cheats are re-applied.
  public static func TickSeconds() -> Float = 1.0
  // Show a short on-screen message when a cheat is toggled.
  public static func ShowMessages() -> Bool = true

  // Cheats that start switched on when a save loads.
  public static func StartGod() -> Bool = false
  public static func StartMoney() -> Bool = false
  public static func StartInvisible() -> Bool = false
  public static func StartCarry() -> Bool = false
}

// ---------------------------------------------------------------------------
// Controller: owns cheat state, input and the re-apply tick for one player.
// ---------------------------------------------------------------------------
public class ChoomCheats extends IScriptable {
  private let m_player: wref<PlayerPuppet>;
  private let m_god: Bool;
  private let m_money: Bool;
  private let m_invisible: Bool;
  private let m_carry: Bool;
  private let m_carryMod: ref<gameStatModifierData>;
  private let m_tickPending: Bool;
  private let m_attached: Bool;

  public static func Create(player: ref<PlayerPuppet>) -> ref<ChoomCheats> {
    let self = new ChoomCheats();
    self.m_player = player;
    return self;
  }

  public func Attach() -> Void {
    let player = this.m_player;
    if !IsDefined(player) { return; }
    this.m_attached = true;
    player.RegisterInputListener(this, n"ChoomToggleGod");
    player.RegisterInputListener(this, n"ChoomToggleMoney");
    player.RegisterInputListener(this, n"ChoomToggleInvisible");
    player.RegisterInputListener(this, n"ChoomToggleCarry");
    this.SetGod(ChoomConfig.StartGod(), false);
    this.SetMoney(ChoomConfig.StartMoney(), false);
    this.SetInvisible(ChoomConfig.StartInvisible(), false);
    this.SetCarry(ChoomConfig.StartCarry(), false);
  }

  public func Detach() -> Void {
    let player = this.m_player;
    this.m_attached = false;
    if !IsDefined(player) { return; }
    // Undo engine-side changes so nothing leaks into a save made without the mod.
    this.SetGod(false, false);
    this.SetInvisible(false, false);
    this.SetCarry(false, false);
    this.m_money = false;
    player.UnregisterInputListener(this);
  }

  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if !ListenerAction.IsButtonJustPressed(action) { return false; }
    switch ListenerAction.GetName(action) {
      case n"ChoomToggleGod":
        this.SetGod(!this.m_god, true);
        break;
      case n"ChoomToggleMoney":
        this.SetMoney(!this.m_money, true);
        break;
      case n"ChoomToggleInvisible":
        this.SetInvisible(!this.m_invisible, true);
        break;
      case n"ChoomToggleCarry":
        this.SetCarry(!this.m_carry, true);
        break;
    }
    return false;
  }

  // ---- Infinite health ----------------------------------------------------
  private func SetGod(on: Bool, announce: Bool) -> Void {
    let player = this.m_player;
    if !IsDefined(player) { return; }
    let gods = GameInstance.GetGodModeSystem(player.GetGame());
    if on {
      gods.AddGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"ChoomCheats");
      this.RefillHealth();
    } else {
      gods.RemoveGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"ChoomCheats");
    }
    this.m_god = on;
    this.Changed("Infinite health", on, announce);
  }

  private func RefillHealth() -> Void {
    let player = this.m_player;
    GameInstance.GetStatPoolsSystem(player.GetGame()).RequestSettingStatPoolMaxValue(
      Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, player);
  }

  // ---- Infinite money -----------------------------------------------------
  private func SetMoney(on: Bool, announce: Bool) -> Void {
    this.m_money = on;
    if on { this.TopUpMoney(); }
    this.Changed("Infinite money", on, announce);
  }

  private func TopUpMoney() -> Void {
    let player = this.m_player;
    let ts = GameInstance.GetTransactionSystem(player.GetGame());
    let have = ts.GetItemQuantity(player, MarketSystem.Money());
    let floor = ChoomConfig.MoneyFloor();
    if have < floor {
      ts.GiveItem(player, MarketSystem.Money(), floor - have);
    }
  }

  // ---- Invisibility -------------------------------------------------------
  private func SetInvisible(on: Bool, announce: Bool) -> Void {
    let player = this.m_player;
    if !IsDefined(player) { return; }
    player.SetInvisible(on);
    player.UpdateVisibility();
    this.m_invisible = on;
    this.Changed("Invisible", on, announce);
  }

  // ---- Unlimited carry ----------------------------------------------------
  private func SetCarry(on: Bool, announce: Bool) -> Void {
    let player = this.m_player;
    if !IsDefined(player) { return; }
    let stats = GameInstance.GetStatsSystem(player.GetGame());
    let id = Cast<StatsObjectID>(player.GetEntityID());
    if on && !IsDefined(this.m_carryMod) {
      this.m_carryMod = RPGManager.CreateStatModifier(
        gamedataStatType.CarryCapacity, gameStatModifierType.Additive, ChoomConfig.CarryBonus());
      stats.AddModifier(id, this.m_carryMod);
      this.ClearEncumbered();
    } else if !on && IsDefined(this.m_carryMod) {
      stats.RemoveModifier(id, this.m_carryMod);
      this.m_carryMod = null;
    }
    this.m_carry = on;
    this.Changed("Unlimited carry", on, announce);
  }

  private func ClearEncumbered() -> Void {
    StatusEffectHelper.RemoveStatusEffect(this.m_player, t"BaseStatusEffect.Encumbered");
  }

  // ---- Re-apply tick ------------------------------------------------------
  // God mode and the stat modifier persist on their own; health, money and
  // the encumbered effect can drift, so they are re-applied while active.
  private func AnyActive() -> Bool {
    return this.m_god || this.m_money || this.m_invisible || this.m_carry;
  }

  private func ScheduleTick() -> Void {
    if this.m_tickPending || !this.m_attached || !this.AnyActive() { return; }
    let player = this.m_player;
    if !IsDefined(player) { return; }
    let cb = new ChoomCheatsTick();
    cb.m_owner = this;
    this.m_tickPending = true;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(cb, ChoomConfig.TickSeconds(), false);
  }

  public func Tick() -> Void {
    this.m_tickPending = false;
    if !this.m_attached || !IsDefined(this.m_player) { return; }
    if this.m_god { this.RefillHealth(); }
    if this.m_money { this.TopUpMoney(); }
    if this.m_carry { this.ClearEncumbered(); }
    this.ScheduleTick();
  }

  // ---- Feedback -----------------------------------------------------------
  private func Changed(label: String, on: Bool, announce: Bool) -> Void {
    this.ScheduleTick();
    if !announce || !ChoomConfig.ShowMessages() { return; }
    let player = this.m_player;
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = 2.0;
    msg.message = label + (on ? ": ON" : ": OFF");
    let defs = GetAllBlackboardDefs();
    GameInstance.GetBlackboardSystem(player.GetGame())
      .Get(defs.UI_Notifications)
      .SetVariant(defs.UI_Notifications.OnscreenMessage, ToVariant(msg), true);
  }
}

public class ChoomCheatsTick extends DelayCallback {
  public let m_owner: wref<ChoomCheats>;

  public func Call() -> Void {
    if IsDefined(this.m_owner) { this.m_owner.Tick(); }
  }
}

// ---------------------------------------------------------------------------
// Lifecycle hooks on the player.
// ---------------------------------------------------------------------------
@addField(PlayerPuppet)
private let m_choomCheats: ref<ChoomCheats>;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  this.m_choomCheats = ChoomCheats.Create(this);
  this.m_choomCheats.Attach();
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  if IsDefined(this.m_choomCheats) {
    this.m_choomCheats.Detach();
    this.m_choomCheats = null;
  }
  return wrappedMethod();
}
