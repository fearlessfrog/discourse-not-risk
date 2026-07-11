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
import { i18n } from "discourse-i18n";
import { formatNotRiskEvent } from "../lib/not-risk-event-formatter";
import NotRiskBattle from "./modal/not-risk-battle";
import NotRiskRules from "./modal/not-risk-rules";
import NotRiskMap from "./not-risk-map";

export default class NotRiskWarRoom extends Component {
  @service messageBus;
  @service modal;
  @service currentUser;

  @tracked state = this.args.model;
  @tracked selectedFrom;
  @tracked selectedTo;
  @tracked armies = 1;
  @tracked moveArmies = 1;
  @tracked busy = false;
  @tracked showDiagnostics = false;

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
      return this.state.permissions?.can_start ? "Ready to start" : "Waiting for the campaign host";
    }

    if (!this.currentPlayer) {
      return "Waiting for turn assignment";
    }

    return `Waiting for ${this.currentPlayer.username} to ${this.phaseLabel}`;
  }

  get actionHint() {
    if (this.game.current_phase === "ended") {
      return "The campaign is complete. Review the map and Battle Log for the final result.";
    }

    if (this.isSetup) {
      return "Join the campaign, then the host or staff can start once at least two players are ready.";
    }

    if (this.game.current_phase === "reinforce") {
      return this.selectedFrom
        ? "Enter how many armies to place here, then deploy."
        : "Choose one of your territories to reinforce.";
    }

    if (this.game.current_phase === "attack") {
      if (!this.selectedFrom) {
        return "Choose one of your territories with at least 2 armies.";
      }
      if (!this.selectedTo) {
        return "Now choose an adjacent enemy territory to attack.";
      }

      return "Choose how many armies to send, then attack. One army must stay behind.";
    }

    if (this.game.current_phase === "fortify") {
      if (this.fortifyUsed) {
        return "Fortification complete. End your turn when you are ready.";
      }
      if (!this.selectedFrom) {
        return "Choose one of your territories to move armies from.";
      }
      if (!this.selectedTo) {
        return "Now choose an adjacent territory you own.";
      }

      return "Enter how many armies to move, then fortify. One army must stay behind.";
    }

    return "Choose your next action.";
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

  get fortifyUsed() {
    return Boolean(this.game.settings?.turn_state?.fortify_used);
  }

  get canDeploy() {
    return this.game.current_phase === "reinforce" && this.selectedFrom;
  }

  get canAttack() {
    return this.game.current_phase === "attack" && this.selectedFrom && this.selectedTo;
  }

  get canFortify() {
    return this.game.current_phase === "fortify" && !this.fortifyUsed && this.selectedFrom && this.selectedTo;
  }

  get canEndTurn() {
    return ["attack", "fortify"].includes(this.game.current_phase);
  }

  get canAdvanceToFortify() {
    return this.game.current_phase === "attack";
  }

  get canStart() {
    return Boolean(this.state.permissions?.can_start);
  }

  get canJoin() {
    return Boolean(this.state.permissions?.can_join);
  }

  get isParticipant() {
    return Boolean(this.state.permissions?.is_participant);
  }

  get isGameFull() {
    return this.players.length >= (this.game.max_players || 4);
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

  eventDisplay = (event) => {
    const player = this.players.find((candidate) => candidate.id === event.player_id);
    const summary = formatNotRiskEvent(event, {
      territoryName: this.territoryName,
      playerName: this.playerName,
    });

    return {
      ...summary,
      hasPlayer: Boolean(player),
      playerStyle: player
        ? htmlSafe(`--not-risk-event-player-color:${player.color}`)
        : undefined,
    };
  };

  playerName = (playerId) => {
    return this.players.find((player) => player.id === playerId)?.username || "Unknown player";
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
    if (this.game.current_phase === "fortify" && this.fortifyUsed) {
      return;
    }

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
  clearTerritorySelection() {
    this.selectedFrom = null;
    this.selectedTo = null;
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
  updateDiagnostics(event) {
    this.showDiagnostics = event.target.checked;
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
    const source = this.state.territories.find((territory) => territory.key === this.selectedFrom);
    const target = this.state.territories.find((territory) => territory.key === this.selectedTo);

    this.modal.show(NotRiskBattle, {
      model: {
        attacker: this.ownerFor(source),
        defender: this.ownerFor(target),
        fromName: source.name,
        toName: target.name,
        sourceArmies: source.armies,
        targetArmies: target.armies,
        resolveAttack: this.resolveAttack,
      },
    });
  }

  resolveAttack = async () => {
    this.busy = true;
    try {
      const response = await ajax(`/not-risk/games/${this.game.id}/attack.json`, {
        type: "POST",
        data: {
          from_key: this.selectedFrom,
          to_key: this.selectedTo,
          attack_armies: this.moveArmies,
          move_armies: this.moveArmies,
        },
      });
      this.state = response;
      this.selectedFrom = null;
      this.selectedTo = null;
      return response.action_result;
    } catch (error) {
      popupAjaxError(error);
      throw error;
    } finally {
      this.busy = false;
    }
  };

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

  @action
  join() {
    return this.postAction("join");
  }

  @action
  showRules() {
    this.modal.show(NotRiskRules);
  }

  <template>
    <main class="not-risk-war-room">
      <header class="not-risk-war-room__header">
        <div>
          <h1>{{this.game.name}}</h1>
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
            @onClearSelection={{this.clearTerritorySelection}}
          />
        </div>

        <aside class="not-risk-war-room__side">
          <section class="not-risk-panel">
            <h2>Action</h2>
            <p class="not-risk-action-hint">{{this.actionHint}}</p>

            {{#if (eq this.game.current_phase "reinforce")}}
              {{#if this.selectedFrom}}
                <p class="not-risk-action-selection">
                  <span>Selected</span>
                  <strong>{{this.selectedFromName}}</strong>
                </p>
              {{/if}}
            {{else}}
              {{#if this.selectedFrom}}
                <p class="not-risk-action-selection">
                  <span>From</span>
                  <strong>{{this.selectedFromName}}</strong>
                </p>
              {{/if}}
              {{#if this.selectedTo}}
                <p class="not-risk-action-selection">
                  <span>To</span>
                  <strong>{{this.selectedToName}}</strong>
                </p>
              {{/if}}
            {{/if}}

            {{#if (eq this.game.current_phase "reinforce")}}
              {{#if this.isSetup}}
                <p class="not-risk-muted">
                  {{this.players.length}} of {{this.game.max_players}} players joined.
                </p>
                {{#if this.canJoin}}
                  <DButton
                    @action={{this.join}}
                    @label="not_risk.join_game"
                    @disabled={{this.busy}}
                    class="btn-primary not-risk-setup-action"
                  />
                {{else if this.isParticipant}}
                  <p class="not-risk-setup-status">{{i18n "not_risk.joined"}}</p>
                {{else if this.isGameFull}}
                  <p class="not-risk-setup-status">{{i18n "not_risk.game_full"}}</p>
                {{else if (not this.currentUser)}}
                  <p class="not-risk-muted">{{i18n "not_risk.login_to_join"}}</p>
                {{/if}}
                <DButton
                  @action={{this.start}}
                  @label="not_risk.start_campaign"
                  @disabled={{or this.busy (not this.canStart)}}
                  class="btn-primary not-risk-setup-action"
                />
              {{else}}
                <label class="not-risk-field">
                  Armies to deploy
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
              {{#if this.selectedFromTerritory}}
                <p class="not-risk-muted">
                  Source armies: {{this.selectedFromTerritory.armies}}.
                  Max attack: {{this.maxAttackArmies}}. Rolls up to 3 dice.
                </p>
              {{/if}}
              <DButton
                @action={{this.attack}}
                @label="not_risk.attack"
                @disabled={{or this.busy (not this.canAttack)}}
                class="btn-primary"
              />
              <div class="not-risk-action-advance">
                <span>Done attacking? Move on to fortify.</span>
                <DButton
                  @action={{this.advanceToFortify}}
                  @label="not_risk.advance_to_fortify"
                  @disabled={{or this.busy (not this.canAdvanceToFortify)}}
                  class="not-risk-action-secondary"
                />
              </div>
            {{else if (eq this.game.current_phase "fortify")}}
              <label class="not-risk-field">
                Armies to move
                <input
                  type="number"
                  min="1"
                  value={{this.armies}}
                  disabled={{this.fortifyUsed}}
                  {{on "input" this.updateArmies}}
                />
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
              class={{if
                this.fortifyUsed
                "btn-primary not-risk-action-end-turn"
                "not-risk-action-secondary not-risk-action-end-turn"
              }}
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
            <DButton
              @action={{this.showRules}}
              @label="not_risk.rules"
              @icon="circle-info"
              class="not-risk-rules-button"
            />
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
        <header class="not-risk-log__header">
          <h2>Battle Log</h2>
          <label class="not-risk-log__diagnostics">
            <input
              type="checkbox"
              checked={{this.showDiagnostics}}
              {{on "change" this.updateDiagnostics}}
            />
            Diagnostics
          </label>
        </header>
        {{#each this.state.events as |event|}}
          {{#if this.showDiagnostics}}
            <article>
              <strong>Turn {{event.turn_number}} · {{event.event_type}}</strong>
              <pre>{{this.eventPayload event}}</pre>
            </article>
          {{else}}
            {{#let (this.eventDisplay event) as |display|}}
              <article
                class={{if display.hasPlayer "not-risk-log__player-event"}}
                style={{display.playerStyle}}
              >
                <strong>Turn {{event.turn_number}} · {{display.label}}</strong>
                {{#each display.lines as |line|}}
                  <p>{{line}}</p>
                {{/each}}
              </article>
            {{/let}}
          {{/if}}
        {{/each}}
      </section>
    </main>
  </template>
}
