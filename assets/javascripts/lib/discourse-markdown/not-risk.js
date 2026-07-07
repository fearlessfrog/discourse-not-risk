function notRisk(buffer, matches, state, { parseBBCodeTag }) {
  const parsed = parseBBCodeTag(matches[0], 0, matches[0].length);
  const gameId = parseInt(parsed?.attrs?.game, 10);

  if (parsed?.tag !== "not-risk" || !gameId || gameId < 1) {
    return;
  }

  const token = new state.Token("span_open", "span", 1);
  token.attrs = [
    ["class", "not-risk-game"],
    ["data-game-id", String(gameId)],
  ];
  buffer.push(token);
  buffer.push(new state.Token("span_close", "span", -1));
}

export function setup(helper) {
  helper.allowList(["span.not-risk-game", "span[data-game-id]"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.notRisk = siteSettings.not_risk_enabled;
  });

  helper.registerPlugin((md) => {
    if (md.options.discourse.features.notRisk) {
      md.core.textPostProcess.ruler.push("not-risk", {
        matcher: /\[not-risk game=\d+\]/,
        onMatch: notRisk,
      });
    }
  });
}
