import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, later } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const FINAL_STAGE = 4;

export default class NotRiskBattle extends Component {
  @tracked result;
  @tracked stage = 0;

  timers = [];

  troopsFor = (side) => {
    const count = side === "attacker" ? this.attackerArmies : this.defenderArmies;
    return Array.from({ length: Math.min(count, 5) });
  };

  troopOverflow = (side) => {
    const count = side === "attacker" ? this.attackerArmies : this.defenderArmies;
    return Math.max(count - 5, 0);
  };

  troopClass = (side, index) => {
    if (!this.showComparison || this.isComplete) {
      return "";
    }

    const losses = side === "attacker" ? this.attackerLosses : this.defenderLosses;
    const visibleTroops = this.troopsFor(side).length;
    return index >= visibleTroops - losses ? "is-casualty" : "";
  };

  attackerDieClass = (index) => {
    if (!this.showComparison || index >= this.result.defender_dice.length) {
      return "";
    }

    return this.result.attacker_dice[index] <= this.result.defender_dice[index] ? "is-loser" : "is-winner";
  };

  defenderDieClass = (index) => {
    if (!this.showComparison || index >= this.result.attacker_dice.length) {
      return "";
    }

    return this.result.attacker_dice[index] > this.result.defender_dice[index] ? "is-loser" : "is-winner";
  };

  willDestroy() {
    super.willDestroy(...arguments);
    this.cancelTimers();
  }

  get isComplete() {
    return this.stage === FINAL_STAGE;
  }

  get isRevealing() {
    return this.result && !this.isComplete;
  }

  get showAttackerDice() {
    return this.stage >= 1;
  }

  get showDefenderDice() {
    return this.stage >= 2;
  }

  get showComparison() {
    return this.stage >= 3;
  }

  get attackerArmies() {
    if (!this.result) {
      return this.args.model.sourceArmies;
    }

    return this.isComplete ? this.result.source_armies_after : this.result.source_armies_before;
  }

  get defenderArmies() {
    if (!this.result) {
      return this.args.model.targetArmies;
    }

    if (!this.isComplete) {
      return this.result.target_armies_before;
    }

    return this.result.captured ? 0 : this.result.target_armies_after;
  }

  get attackerLosses() {
    return this.result?.losses?.attacker || 0;
  }

  get defenderLosses() {
    return this.result?.losses?.defender || 0;
  }

  get outcome() {
    if (this.result.captured) {
      return `Conquered ${this.args.model.toName}!`;
    }
    if (this.defenderLosses > this.attackerLosses) {
      return "Victory!";
    }
    if (this.attackerLosses > this.defenderLosses) {
      return "Defeat!";
    }

    return "Costly exchange";
  }

  get outcomeDetail() {
    if (this.result.captured) {
      const moved = this.result.moved;
      return `${moved} ${moved === 1 ? "army moves" : "armies move"} into the conquered territory.`;
    }

    return `Attacker losses: ${this.attackerLosses}. Defender losses: ${this.defenderLosses}.`;
  }

  get attackerStyle() {
    return trustHTML(`--not-risk-battle-color:${this.args.model.attacker.color}`);
  }

  get defenderStyle() {
    return trustHTML(`--not-risk-battle-color:${this.args.model.defender.color}`);
  }

  @action
  async resolveAttack() {
    try {
      this.result = await this.args.model.resolveAttack();
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        this.stage = FINAL_STAGE;
        return;
      }

      this.stage = 1;
      this.timers.push(later(() => (this.stage = 2), 750));
      this.timers.push(later(() => (this.stage = 3), 1_650));
      this.timers.push(later(() => (this.stage = FINAL_STAGE), 2_750));
    } catch {
      this.args.closeModal();
    }
  }

  cancelTimers() {
    this.timers.forEach((timer) => cancel(timer));
    this.timers = [];
  }

  @action
  skipReveal() {
    this.cancelTimers();
    this.stage = FINAL_STAGE;
  }

  @action
  continuePlaying() {
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{if this.isComplete "Battle Result" "Attacking!"}}
      @closeModal={{this.continuePlaying}}
      @dismissable={{this.isComplete}}
      class="not-risk-battle-modal"
    >
      <:body>
        <div class="not-risk-battle" {{didInsert this.resolveAttack}}>
          <div class="not-risk-battle__forces">
            <section class="not-risk-battle__force is-attacker" style={{this.attackerStyle}}>
              <span>Attacker</span>
              <strong>{{@model.attacker.username}}</strong>
              <small>{{@model.fromName}}</small>
              <div class="not-risk-battle__troops" aria-label="{{this.attackerArmies}} attacking armies">
                {{#each (this.troopsFor "attacker") as |_troop index|}}
                  <i class={{this.troopClass "attacker" index}}>{{dIcon "user"}}</i>
                {{/each}}
                {{#if (this.troopOverflow "attacker")}}
                  <b>+{{this.troopOverflow "attacker"}}</b>
                {{/if}}
              </div>
              <em>{{this.attackerArmies}} armies</em>
            </section>

            <div class="not-risk-battle__versus">VS</div>

            <section class="not-risk-battle__force is-defender" style={{this.defenderStyle}}>
              <span>Defender</span>
              <strong>{{@model.defender.username}}</strong>
              <small>{{@model.toName}}</small>
              <div class="not-risk-battle__troops" aria-label="{{this.defenderArmies}} defending armies">
                {{#each (this.troopsFor "defender") as |_troop index|}}
                  <i class={{this.troopClass "defender" index}}>{{dIcon "shield-halved"}}</i>
                {{/each}}
                {{#if (this.troopOverflow "defender")}}
                  <b>+{{this.troopOverflow "defender"}}</b>
                {{/if}}
              </div>
              <em>{{this.defenderArmies}} armies</em>
            </section>
          </div>

          {{#if this.result}}
            <div class="not-risk-battle__dice">
              <section class={{if this.showAttackerDice "is-visible"}}>
                <span>Attacker rolled</span>
                <div>
                  {{#each this.result.attacker_dice as |die index|}}
                    <b class={{this.attackerDieClass index}}>{{die}}</b>
                  {{/each}}
                </div>
              </section>
              <section class={{if this.showDefenderDice "is-visible"}}>
                <span>Defender rolled</span>
                <div>
                  {{#each this.result.defender_dice as |die index|}}
                    <b class={{this.defenderDieClass index}}>{{die}}</b>
                  {{/each}}
                </div>
              </section>
            </div>
          {{else}}
            <p class="not-risk-battle__rolling">The armies are taking their positions…</p>
          {{/if}}

          {{#if this.showComparison}}
            <div class="not-risk-battle__casualties">
              <span>Attackers lost <strong>{{this.attackerLosses}}</strong></span>
              <span>Defenders lost <strong>{{this.defenderLosses}}</strong></span>
            </div>
          {{/if}}

          {{#if this.isComplete}}
            <div class="not-risk-battle__outcome">
              <strong>{{this.outcome}}</strong>
              <p>{{this.outcomeDetail}}</p>
            </div>
          {{/if}}
        </div>
      </:body>

      <:footer>
        {{#if this.isComplete}}
          <DButton
            @action={{this.continuePlaying}}
            @translatedLabel="Continue"
            class="btn-primary"
          />
        {{else if this.isRevealing}}
          <DButton
            @action={{this.skipReveal}}
            @translatedLabel="Skip Reveal"
            class="btn-transparent"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
