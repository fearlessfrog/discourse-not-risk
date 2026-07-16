import { module, test } from "qunit";
import { formatReinforcementBreakdown } from "discourse/plugins/discourse-not-risk/discourse/lib/not-risk-event-formatter";

module("Unit | Not Risk | event formatter", function () {
  test("formats the base allowance and territory bonuses", function (assert) {
    const text = formatReinforcementBreakdown(
      {
        territory_count: 4,
        base_armies: 4,
        bonuses: [{ territory: "central_kingdom", armies: 1 }],
        total_armies: 5,
      },
      { territoryName: () => "Central Kingdom" }
    );

    assert.strictEqual(
      text,
      "4 territories: 4 base +1 Central Kingdom = 5 armies."
    );
  });

  test("identifies a bonus-free opening deployment", function (assert) {
    const text = formatReinforcementBreakdown(
      {
        territory_count: 4,
        base_armies: 4,
        bonuses: [],
        total_armies: 4,
        opening_deployment: true,
      },
      { territoryName: () => "unused" }
    );

    assert.strictEqual(
      text,
      "Opening deployment — 4 territories: 4 base = 4 armies."
    );
  });
});
