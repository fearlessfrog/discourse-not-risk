import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import NotRiskMap from "./not-risk-map";

export default class NotRiskWarRoom extends Component {
  @service messageBus;

  @tracked state = this.args.model;
  @tracked selectedFrom;
  @tracked selectedTo;
  @tracked armies = 1;
  @tracked moveArmies = 1;
  @tracked busy = false;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(this.channel, this.refreshFromBus);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.channel, this.refreshFromBus);
  }

  get game() {
    return this.state.game;
  }

  get channel() {
    return `/not-risk/games/${this.game.id}`;
  }

  get players() {
    return this.state.players || [];
  }

  get currentPlayer() {
    return this.players.find((player) => player.id === this.game.current_player_id);
  }

  get isSetup() {
    return this.game.status === "setup";
  }

  get phaseLabel() {
    if (this.isSetup) {
      return "setup";
    }

    return this.game.current_phase?.replace("_", " ") || "setup";
  }

  get turnStatus() {
    if (this.game.current_phase === "ended") {
      return "Campaign ended";
    }

    if (this.isSetup && this.players.length < 2) {
      return "Waiting for players";
    }

    if (this.isSetup) {
      return "Ready for staff to start";
    }

    if (!this.currentPlayer) {
      return "Waiting for turn assignment";
    }

    return `Waiting for ${this.currentPlayer.username} to ${this.phaseLabel}`;
  }

  get selectedFromName() {
    return this.territoryName(this.selectedFrom);
  }

  get selectedToName() {
    return this.territoryName(this.selectedTo);
  }

  get selectedFromTerritory() {
    return this.state.territories?.find((territory) => territory.key === this.selectedFrom);
  }

  get maxAttackArmies() {
    return Math.max((this.selectedFromTerritory?.armies || 0) - 1, 0);
  }

  get canDeploy() {
    return this.game.current_phase === "reinforce" && this.selectedFrom;
  }

  get canAttack() {
    return this.game.current_phase === "attack" && this.selectedFrom && this.selectedTo;
  }

  get canFortify() {
    return this.game.current_phase === "fortify" && this.selectedFrom && this.selectedTo;
  }

  get canEndTurn() {
    return ["attack", "fortify"].includes(this.game.current_phase);
  }

  get canAdvanceToFortify() {
    return this.game.current_phase === "attack";
  }

  get canStart() {
    return this.isSetup && this.players.length >= 2;
  }

  get topicPath() {
    return `/t/${this.game.topic_id}`;
  }

  territoryName = (key) => {
    if (!key) {
      return "None";
    }
    return this.state.map.territories.find((territory) => territory.key === key)?.name || key;
  };

  playerSwatchStyle = (player) => {
    return htmlSafe(`background:${player.color}`);
  };

  ownerFor = (territory) => {
    return this.players.find((player) => player.id === territory.owner_player_id);
  };

  territoryOwnerStyle = (territory) => {
    return htmlSafe(`background:${this.ownerFor(territory)?.color || "#d4d4d8"}`);
  };

  eventPayload = (event) => {
    return JSON.stringify(event.payload, null, 2);
  };

  refreshFromBus = async () => {
    if (this.busy) {
      return;
    }

    try {
      this.state = await ajax(`/not-risk/games/${this.game.id}.json`);
    } catch {
      // Keep the current state visible; direct actions still surface errors.
      // A transient bus refresh failure should not break the War Room.
    }
  };

  async postAction(path, data = {}) {
    this.busy = true;
    try {
      this.state = await ajax(`/not-risk/games/${this.game.id}/${path}.json`, {
        type: "POST",
        data,
      });
      this.selectedFrom = null;
      this.selectedTo = null;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.busy = false;
    }
  }

  @action
  selectTerritory(territoryKey) {
    if (this.game.current_phase === "reinforce") {
      this.selectedFrom = territoryKey;
      this.selectedTo = null;
      return;
    }

    if (!this.selectedFrom || this.selectedTo) {
      this.selectedFrom = territoryKey;
      this.selectedTo = null;
    } else {
      this.selectedTo = territoryKey;
    }
  }

  @action
  updateArmies(event) {
    this.armies = event.target.value;
  }

  @action
  updateMoveArmies(event) {
    this.moveArmies = event.target.value;
  }

  @action
  deploy() {
    return this.postAction("deploy", {
      territory_key: this.selectedFrom,
      armies: this.armies,
    });
  }

  @action
  attack() {
    return this.postAction("attack", {
      from_key: this.selectedFrom,
      to_key: this.selectedTo,
      attack_armies: this.moveArmies,
      move_armies: this.moveArmies,
    });
  }

  @action
  fortify() {
    return this.postAction("fortify", {
      from_key: this.selectedFrom,
      to_key: this.selectedTo,
      armies: this.armies,
    });
  }

  @action
  advanceToFortify() {
    return this.postAction("advance_to_fortify");
  }

  @action
  endTurn() {
    return this.postAction("end_turn");
  }

  @action
  start() {
    return this.postAction("start");
  }

  <template>
    <main class="not-risk-war-room">
      <header class="not-risk-war-room__header">
        <div>
          <h1>{{this.game.name}}</h1>
          <p>
            Turn {{this.game.turn_number}} ·
            {{if this.currentPlayer this.currentPlayer.username "Waiting"}} ·
            {{this.phaseLabel}}
          </p>
        </div>
        <a href={{this.topicPath}} class="btn">Campaign Topic</a>
      </header>

      <section class="not-risk-turn-banner">
        <div>
          <span>Current Turn</span>
          <strong>{{this.turnStatus}}</strong>
        </div>
        <div>
          <span>Phase</span>
          <strong>{{this.phaseLabel}}</strong>
        </div>
        <div>
          <span>Turn</span>
          <strong>{{this.game.turn_number}}</strong>
        </div>
      </section>

      <section class="not-risk-war-room__layout">
        <div class="not-risk-war-room__map-panel">
          <NotRiskMap
            @map={{this.state.map}}
            @players={{this.players}}
            @territories={{this.state.territories}}
            @selectedFrom={{this.selectedFrom}}
            @selectedTo={{this.selectedTo}}
            @onSelect={{this.selectTerritory}}
          />
        </div>

        <aside class="not-risk-war-room__side">
          <section class="not-risk-panel">
            <h2>Action</h2>
            <p class="not-risk-muted">
              From: {{this.selectedFromName}}<br />
              To: {{this.selectedToName}}
            </p>

            {{#if (eq this.game.current_phase "reinforce")}}
              {{#if this.isSetup}}
                <p class="not-risk-muted">
                  {{this.players.length}} players joined. Staff can start once at least two players are in.
                </p>
                <DButton
                  @action={{this.start}}
                  @label="not_risk.start_campaign"
                  @disabled={{or this.busy (not this.canStart)}}
                  class="btn-primary"
                />
              {{else}}
                <label class="not-risk-field">
                  Armies
                  <input type="number" min="1" value={{this.armies}} {{on "input" this.updateArmies}} />
                </label>
                <DButton
                  @action={{this.deploy}}
                  @label="not_risk.deploy"
                  @disabled={{or this.busy (not this.canDeploy)}}
                  class="btn-primary"
                />
                <p class="not-risk-muted">
                  Reinforcements left:
                  {{this.game.settings.turn_state.reinforcements_remaining}}
                </p>
              {{/if}}
            {{else if (eq this.game.current_phase "attack")}}
              <label class="not-risk-field">
                Attack armies
                <input
                  type="number"
                  min="1"
                  max={{this.maxAttackArmies}}
                  value={{this.moveArmies}}
                  {{on "input" this.updateMoveArmies}}
                />
              </label>
              <p class="not-risk-muted">
                Source armies: {{if this.selectedFromTerritory this.selectedFromTerritory.armies "none"}}.
                Max attack: {{this.maxAttackArmies}}. Rolls up to 3 dice.
              </p>
              <DButton
                @action={{this.attack}}
                @label="not_risk.attack"
                @disabled={{or this.busy (not this.canAttack)}}
                class="btn-primary"
              />
              <DButton
                @action={{this.advanceToFortify}}
                @label="not_risk.advance_to_fortify"
                @disabled={{or this.busy (not this.canAdvanceToFortify)}}
              />
            {{else if (eq this.game.current_phase "fortify")}}
              <label class="not-risk-field">
                Armies
                <input type="number" min="1" value={{this.armies}} {{on "input" this.updateArmies}} />
              </label>
              <DButton
                @action={{this.fortify}}
                @label="not_risk.fortify"
                @disabled={{or this.busy (not this.canFortify)}}
                class="btn-primary"
              />
            {{/if}}

            <DButton
              @action={{this.endTurn}}
              @label="not_risk.end_turn"
              @disabled={{or this.busy (not this.canEndTurn)}}
            />
          </section>

          <section class="not-risk-panel">
            <h2>Players</h2>
            <ol class="not-risk-player-list">
              {{#each this.players as |player|}}
                <li class={{if (eq player.id this.game.current_player_id) "is-current-player"}}>
                  <span style={{this.playerSwatchStyle player}}></span>
                  <strong>{{player.username}}</strong>
                  {{#if (eq player.id this.game.current_player_id)}}
                    <em>Turn</em>
                  {{/if}}
                  {{#if player.eliminated}}(out){{/if}}
                </li>
              {{/each}}
            </ol>
          </section>

          <section class="not-risk-panel">
            <h2>Territories</h2>
            <div class="not-risk-territory-list">
              {{#each this.state.territories as |territory|}}
                <div>
                  <span class="not-risk-territory-list__owner" style={{this.territoryOwnerStyle territory}}></span>
                  <strong>{{territory.name}}</strong>
                  {{#if territory.bonus}}
                    <em>+{{territory.bonus}}</em>
                  {{/if}}
                  <span class="not-risk-territory-list__armies">{{territory.armies}}</span>
                </div>
              {{/each}}
            </div>
          </section>
        </aside>
      </section>

      <nav class="not-risk-war-room__return" aria-label="Campaign navigation">
        <a href={{this.topicPath}} class="btn btn-primary">Return to Topic</a>
      </nav>

      <section class="not-risk-panel not-risk-log">
        <h2>Battle Log</h2>
        {{#each this.state.events as |event|}}
          <article>
            <strong>Turn {{event.turn_number}} · {{event.event_type}}</strong>
            <pre>{{this.eventPayload event}}</pre>
          </article>
        {{/each}}
      </section>
    </main>
  </template>
}
