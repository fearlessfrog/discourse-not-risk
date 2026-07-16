export function hasAvailableFortification(state) {
  const currentPlayerId = state?.game?.current_player_id;
  if (!currentPlayerId) {
    return false;
  }

  const territories = new Map(
    (state.territories || []).map((territory) => [territory.key, territory])
  );

  return (state.map?.connections || []).some((connection) => {
    const from = territories.get(connection.from);
    const to = territories.get(connection.to);
    const bothOwned =
      from?.owner_player_id === currentPlayerId &&
      to?.owner_player_id === currentPlayerId;

    return bothOwned && (from.armies > 1 || to.armies > 1);
  });
}

export function shouldConfirmEndTurn(state) {
  if (state?.game?.current_phase === "attack") {
    return true;
  }

  return (
    state?.game?.current_phase === "fortify" &&
    !state?.game?.settings?.turn_state?.fortify_used &&
    hasAvailableFortification(state)
  );
}
