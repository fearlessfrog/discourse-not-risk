import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const NotRiskRules = <template>
  <DModal
    @title={{i18n "not_risk.rules"}}
    @closeModal={{@closeModal}}
    class="not-risk-rules-modal"
  >
    <:body>
      <div class="not-risk-rules">
        <section>
          <h3>Starting a campaign</h3>
          <ol>
            <li>Players join, then staff starts the campaign.</li>
            <li>
              Everyone rolls for order automatically once started. The highest roll goes first; tied players keep their join order.
            </li>
            <li>
              Territory ownership is shuffled and every territory begins with one army.
            </li>
          </ol>
          <p>
            The three fixed bonus territories are shared across players before the rest are dealt, so one player
            cannot begin with all three. One other non-bonus territory is also randomly chosen to be worth +1 for
            the whole campaign. It will not start with the player who receives Central Kingdom.
          </p>
        </section>

        <section>
          <h3>Territory bonuses</h3>
          <p>Hold these territories when your turn begins to receive extra armies:</p>
          <ul>
            <li><strong>Central Kingdom:</strong> +2 armies</li>
            <li><strong>Southern Bay:</strong> +1 army</li>
            <li><strong>Isle of Mists:</strong> +1 army</li>
          </ul>
          <p>
            The randomly chosen bonus territory is marked +1 in the territory list and keeps that value even when
            it changes hands.
          </p>
        </section>

        <section>
          <h3>Your turn</h3>
          <ol>
            <li>
              <strong>Reinforce:</strong> Count one army for every two territories you own, rounding down, then add
              your territory bonuses. You always receive at least three armies.
            </li>
            <li>
              <strong>Attack:</strong> Attack any adjacent enemy territory as many times as you like. You must leave
              at least one army behind. The server rolls up to three attacker dice and two defender dice; the
              defender wins ties.
            </li>
            <li>
              <strong>Fortify:</strong> When you are done attacking, advance to fortify. You may make one move between
              two adjacent territories you own, again leaving at least one army behind.
            </li>
            <li><strong>End turn:</strong> Finish your turn and play passes to the next active player.</li>
          </ol>
        </section>

        <p class="not-risk-rules__victory">
          Capture every opponent's last territory to eliminate them. The last player with territory wins the
          campaign.
        </p>
      </div>
    </:body>
  </DModal>
</template>;

export default NotRiskRules;
