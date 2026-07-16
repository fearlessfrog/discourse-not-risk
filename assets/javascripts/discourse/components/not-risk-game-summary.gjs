import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import NotRiskMap from "./not-risk-map";

export default class NotRiskGameSummary extends Component {
  @service messageBus;

  @tracked state;
  @tracked error;

  constructor() {
    super(...arguments);
    this.load();
    this.messageBus.subscribe(this.channel, this.refreshFromBus);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.channel, this.refreshFromBus);
  }

  get channel() {
    return `/not-risk/games/${this.args.gameId}`;
  }

  async load() {
    try {
      this.state = await ajax(`/not-risk/games/${this.args.gameId}.json`);
    } catch (e) {
      this.error =
        e?.jqXHR?.responseJSON?.errors?.join(", ") ||
        e?.jqXHR?.statusText ||
        "Unable to load campaign";
    }
  }

  refreshFromBus = async () => {
    await this.load();
  };

  get game() {
    return this.state?.game;
  }

  get currentPlayer() {
    return this.state?.players?.find(
      (player) => player.id === this.game?.current_player_id
    );
  }

  get isSetup() {
    return this.game?.status === "setup";
  }

  get isOpeningDeployment() {
    return Boolean(this.game?.settings?.turn_state?.opening_deployment);
  }

  get phaseLabel() {
    if (this.isSetup) {
      return "setup";
    }

    if (this.isOpeningDeployment) {
      return "opening deployment";
    }

    return this.game?.current_phase?.replace("_", " ") || "setup";
  }

  get turnStatus() {
    if (this.game?.current_phase === "ended") {
      return "Campaign ended";
    }

    if (this.isSetup && (this.state?.players?.length || 0) < 2) {
      return "Waiting for players";
    }

    if (this.isSetup) {
      return "Ready for staff to start";
    }

    if (!this.currentPlayer) {
      return "Waiting for turn assignment";
    }

    if (this.isOpeningDeployment) {
      return `Waiting for ${this.currentPlayer.username} to deploy opening armies`;
    }

    return `Waiting for ${this.currentPlayer.username} to ${this.phaseLabel}`;
  }

  get warRoomPath() {
    return `/not-risk/games/${this.game.id}`;
  }

  <template>
    <section class="not-risk-summary">
      {{#if this.error}}
        <p class="not-risk-muted">{{this.error}}</p>
      {{else if this.state}}
        <div class="not-risk-summary__body">
          <div class="not-risk-summary__info">
            <h3>{{this.game.name}}</h3>
            <div class="not-risk-summary__turn">
              <span>Current Turn</span>
              <strong>{{this.turnStatus}}</strong>
            </div>
            <dl>
              <div>
                <dt>Current player</dt>
                <dd>{{if this.currentPlayer this.currentPlayer.username "Waiting"}}</dd>
              </div>
              <div>
                <dt>Phase</dt>
                <dd>{{this.phaseLabel}}</dd>
              </div>
            </dl>
            <a href={{this.warRoomPath}} class="btn btn-primary">Open War Room</a>
          </div>
          <NotRiskMap
            @compact={{true}}
            @map={{this.state.map}}
            @players={{this.state.players}}
            @territories={{this.state.territories}}
          />
        </div>
      {{else}}
        <p class="not-risk-muted">Loading campaign...</p>
      {{/if}}
    </section>
  </template>
}
