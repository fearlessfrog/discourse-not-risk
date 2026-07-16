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
            <li>Campaigns support 2–4 players. The creator joins automatically, and other players join from the War Room.</li>
            <li>The campaign creator or staff starts the game once at least two players have joined.</li>
            <li>
              Everyone rolls for order automatically once started. The highest roll goes first; tied players keep their join order.
            </li>
            <li>
              Territory ownership is shuffled and every territory begins with one army.
            </li>
          </ol>
          <p>
            The three fixed bonus territories are shared across players before the rest are dealt, so one player
            cannot begin with all three.
          </p>
          <p>
            Before Turn 1, every player deploys their territory-count base allowance without bonuses. Attacks begin
            only after all opening armies have been placed.
          </p>
        </section>

        <section>
          <h3>Territory bonuses</h3>
          <p>Hold these territories when your turn begins to receive extra armies:</p>
          <ul>
            <li><strong>Central Kingdom:</strong> +1 army</li>
            <li><strong>Southern Bay:</strong> +1 army</li>
            <li><strong>Isle of Mists:</strong> +1 army</li>
          </ul>
          <p>
            Bonus territories keep their +1 value when they change hands.
          </p>
        </section>

        <section>
          <h3>Your turn</h3>
          <ol>
            <li>
              <strong>Reinforce:</strong> Receive 3 base armies for 1–3 territories, 4 for 4–8, or 5 for 9 or
              more. Then add your territory bonuses.
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
