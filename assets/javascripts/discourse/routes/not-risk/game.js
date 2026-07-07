import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class NotRiskGameRoute extends DiscourseRoute {
  @service router;

  model(params) {
    return ajax(`/not-risk/games/${params.game_id}.json`).catch(() =>
      this.router.replaceWith("/404")
    );
  }
}
