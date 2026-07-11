import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class NotRiskNewGame extends Component {
  @service router;

  @tracked title = "";
  @tracked description = "";
  @tracked busy = false;

  get cannotSubmit() {
    return this.busy || !this.title.trim();
  }

  @action
  updateTitle(event) {
    this.title = event.target.value;
  }

  @action
  updateDescription(event) {
    this.description = event.target.value;
  }

  @action
  async createGame(event) {
    event?.preventDefault();
    if (this.cannotSubmit) {
      return;
    }

    this.busy = true;
    try {
      const state = await ajax("/not-risk/games.json", {
        type: "POST",
        data: {
          category_id: this.args.model.category.id,
          name: this.title.trim(),
          description: this.description.trim(),
        },
      });
      this.args.closeModal();
      this.router.transitionTo("not-risk.game", state.game.id);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "not_risk.new_game_title"}}
      @closeModal={{@closeModal}}
      class="not-risk-new-game-modal"
    >
      <:body>
        <form class="not-risk-new-game-form" {{on "submit" this.createGame}}>
          <label>
            <span>{{i18n "not_risk.campaign_title"}}</span>
            <input
              type="text"
              value={{this.title}}
              required
              autofocus
              disabled={{this.busy}}
              {{on "input" this.updateTitle}}
            />
          </label>
          <label>
            <span>{{i18n "not_risk.campaign_description"}}</span>
            <textarea
              rows="6"
              value={{this.description}}
              disabled={{this.busy}}
              {{on "input" this.updateDescription}}
            ></textarea>
          </label>
        </form>
      </:body>
      <:footer>
        <DButton
          @action={{this.createGame}}
          @label="not_risk.create_game"
          @disabled={{this.cannotSubmit}}
          class="btn-primary"
        />
        <DButton @action={{@closeModal}} @label="cancel" @disabled={{this.busy}} />
      </:footer>
    </DModal>
  </template>
}
