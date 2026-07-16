import { module, test } from "qunit";
import {
  hasAvailableFortification,
  shouldConfirmEndTurn,
} from "discourse/plugins/discourse-not-risk/discourse/lib/not-risk-turn";

function state({ phase = "attack", fortifyUsed = false, armies = [2, 1], owners = [1, 1] } = {}) {
  return {
    game: {
      current_player_id: 1,
      current_phase: phase,
      settings: { turn_state: { fortify_used: fortifyUsed } },
    },
    territories: [
      { key: "one", owner_player_id: owners[0], armies: armies[0] },
      { key: "two", owner_player_id: owners[1], armies: armies[1] },
    ],
    map: { connections: [{ from: "one", to: "two" }] },
  };
}

module("Unit | Not Risk | turn helpers", function () {
  test("finds an available fortification in either direction", function (assert) {
    assert.true(hasAvailableFortification(state()));
    assert.true(hasAvailableFortification(state({ armies: [1, 2] })));
  });

  test("rejects unavailable fortifications", function (assert) {
    assert.false(hasAvailableFortification(state({ armies: [1, 1] })));
    assert.false(hasAvailableFortification(state({ owners: [1, 2] })));
  });

  test("always confirms during attack and only confirms an available fortification", function (assert) {
    assert.true(shouldConfirmEndTurn(state({ phase: "attack" })));
    assert.true(
      shouldConfirmEndTurn(state({ phase: "attack", armies: [1, 1] }))
    );
    assert.true(shouldConfirmEndTurn(state({ phase: "fortify" })));
    assert.false(shouldConfirmEndTurn(state({ phase: "reinforce" })));
    assert.false(shouldConfirmEndTurn(state({ fortifyUsed: true })));
    assert.false(shouldConfirmEndTurn(state({ armies: [1, 1] })));
  });
});
