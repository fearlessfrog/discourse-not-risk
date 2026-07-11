import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import NotRiskNewGame from "./modal/not-risk-new-game";

export default class NotRiskNewGameButton extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  get category() {
    return this.args.outletArgs?.category;
  }

  get configuredCategoryIds() {
    return String(this.siteSettings.not_risk_game_categories || "")
      .split("|")
      .map(Number);
  }

  get shouldShow() {
    return Boolean(
      this.currentUser &&
        this.category?.id &&
        this.args.outletArgs?.canCreateTopic &&
        !this.args.outletArgs?.createTopicDisabled &&
        this.configuredCategoryIds.includes(this.category.id)
    );
  }

  @action
  createGame() {
    this.modal.show(NotRiskNewGame, { model: { category: this.category } });
  }

  <template>
    {{#if this.shouldShow}}
      <DButton
        @action={{this.createGame}}
        @label="not_risk.new_game"
        @icon="flag"
        class="btn-primary not-risk-new-game-button"
      />
    {{/if}}
  </template>
}
