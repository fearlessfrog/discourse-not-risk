const EVENT_LABELS = {
  game_created: "Game created",
  player_joined: "Player joined",
  game_started: "Campaign started",
  reinforcements_granted: "Reinforcements granted",
  opening_deployment_completed: "Opening deployment completed",
  deploy: "Reinforcements deployed",
  attack: "Attack",
  advance_to_fortify: "Fortification phase",
  fortify: "Territory fortified",
  turn_ended: "Turn ended",
  game_ended: "Campaign ended",
};

function armies(count) {
  return `${count} ${count === 1 ? "army" : "armies"}`;
}

function dice(values) {
  return Array.isArray(values) && values.length ? values.join(", ") : "none";
}

function humanizeEventType(eventType) {
  if (!eventType) {
    return "Campaign event";
  }

  return eventType
    .split("_")
    .filter(Boolean)
    .map((word, index) =>
      index === 0 ? `${word.charAt(0).toUpperCase()}${word.slice(1)}` : word
    )
    .join(" ");
}

export function formatReinforcementBreakdown(payload, { territoryName }) {
  if (!payload) {
    return "";
  }

  const territoryLabel =
    payload.territory_count === 1 ? "territory" : "territories";
  const parts = [
    `${payload.territory_count} ${territoryLabel}: ${payload.base_armies} base`,
  ];

  for (const bonus of payload.bonuses || []) {
    parts.push(`+${bonus.armies} ${territoryName(bonus.territory)}`);
  }

  const prefix = payload.opening_deployment ? "Opening deployment — " : "";
  return `${prefix}${parts.join(" ")} = ${payload.total_armies} armies.`;
}

export function formatNotRiskEvent(event, { territoryName, playerName }) {
  const payload = event.payload || {};
  const actor = event.username || "A player";
  const label = EVENT_LABELS[event.event_type] || humanizeEventType(event.event_type);

  switch (event.event_type) {
    case "game_created":
      return { label, lines: [`Campaign "${payload.name || "Untitled"}" was created.`] };
    case "player_joined":
      return { label, lines: [`${payload.username || actor} joined the campaign.`] };
    case "game_started": {
      const rolls = (payload.initiative_rolls || []).map(
        (entry) => `${entry.username || playerName(entry.player_id)} rolled ${entry.roll}`
      );
      const order = (payload.player_order || []).map((id) => playerName(id));
      const lines = ["The campaign started."];

      if (rolls.length) {
        lines.push(`Initiative: ${rolls.join("; ")}.`);
      }
      if (order.length) {
        lines.push(`Turn order: ${order.join(", ")}.`);
        lines.push(`${order[0]} takes the first turn.`);
      }
      if (payload.rules_version) {
        lines.push(`Rules v${payload.rules_version}.`);
      }

      return { label, lines };
    }
    case "reinforcements_granted":
      return {
        label,
        lines: [formatReinforcementBreakdown(payload, { territoryName })],
      };
    case "opening_deployment_completed":
      return {
        label,
        lines: [
          `Every player deployed their opening armies. ${payload.first_username || playerName(payload.first_player_id)} begins Turn 1.`,
        ],
      };
    case "deploy":
      return {
        label,
        lines: [
          `${actor} reinforced ${territoryName(payload.territory)} with ${armies(payload.armies)}.`,
        ],
      };
    case "attack": {
      const from = territoryName(payload.from);
      const to = territoryName(payload.to);
      const losses = payload.losses || {};
      const lines = [
        `${actor} attacked ${to} from ${from}.`,
        `Dice: ${actor} rolled ${dice(payload.attacker_dice)}; defender rolled ${dice(payload.defender_dice)}.`,
        `Losses: attacker ${losses.attacker || 0}; defender ${losses.defender || 0}.`,
      ];

      if (payload.captured) {
        lines.push(`${actor} captured ${to} and moved ${armies(payload.moved || 0)} into it.`);
      } else {
        lines.push(`The defender held ${to}.`);
      }

      return { label, lines };
    }
    case "advance_to_fortify":
      return { label, lines: [`${actor} finished attacking and moved to fortification.`] };
    case "fortify":
      return {
        label,
        lines: [
          `${actor} moved ${armies(payload.armies)} from ${territoryName(payload.from)} to ${territoryName(payload.to)}.`,
        ],
      };
    case "turn_ended":
      return {
        label,
        lines: [`${actor} ended their turn.`, `Next player: ${payload.next_username || playerName(payload.next_player_id)}.`],
      };
    case "game_ended":
      return {
        label,
        lines: [`${playerName(payload.winner_player_id)} won the campaign.`],
      };
    default:
      return { label, lines: ["Campaign event recorded."] };
  }
}
