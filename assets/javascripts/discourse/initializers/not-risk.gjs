import { withPluginApi } from "discourse/lib/plugin-api";
import NotRiskGameSummary from "../components/not-risk-game-summary";

function attachNotRiskGames(elem, helper) {
  const nodes = [...elem.querySelectorAll(".not-risk-game")];
  if (!nodes.length || !helper) {
    return;
  }

  nodes.forEach((node) => {
    const gameId = node.dataset.gameId;
    if (!gameId) {
      return;
    }

    const mount = document.createElement("div");
    mount.classList.add("not-risk-game-mount");
    node.replaceWith(mount);
    helper.renderGlimmer(
      mount,
      <template><NotRiskGameSummary @gameId={{gameId}} /></template>
    );
  });
}

export default {
  name: "not-risk",

  initialize() {
    withPluginApi((api) => {
      api.decorateCookedElement(attachNotRiskGames, { onlyStream: true });
    });
  },
};
