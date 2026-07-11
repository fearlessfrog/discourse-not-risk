import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";

export default class NotRiskMap extends Component {
  get territoryState() {
    const state = {};
    this.args.territories?.forEach((territory) => {
      state[territory.key] = territory;
    });
    return state;
  }

  get playerState() {
    const state = {};
    this.args.players?.forEach((player) => {
      state[player.id] = player;
    });
    return state;
  }

  get selectedConnections() {
    if (!this.args.selectedFrom) {
      return [];
    }

    return (this.args.map.connections || []).filter((connection) =>
      [connection.from, connection.to].includes(this.args.selectedFrom)
    );
  }

  fillFor = (territoryKey) => {
    const territory = this.territoryState[territoryKey];
    const player = this.playerState[territory?.owner_player_id];
    return player?.color || "#d4d4d8";
  };

  armyDiscStyle = (territoryKey) => {
    return htmlSafe(`fill:${this.fillFor(territoryKey)}`);
  };

  armiesFor = (territoryKey) => {
    return this.territoryState[territoryKey]?.armies || 0;
  };

  ownerNameFor = (territoryKey) => {
    const territory = this.territoryState[territoryKey];
    return this.playerState[territory?.owner_player_id]?.username || "Unclaimed";
  };

  labelX = (territory) => {
    return territory.label[0];
  };

  labelY = (territory) => {
    return territory.label[1];
  };

  unitsX = (territory) => {
    return territory.units?.[0] || territory.label[0];
  };

  unitsY = (territory) => {
    return territory.units?.[1] || territory.label[1] + 35;
  };

  overlayX = (territory) => {
    return territory.overlay?.cx || territory.label[0];
  };

  overlayY = (territory) => {
    return territory.overlay?.cy || territory.label[1];
  };

  overlayRx = (territory) => {
    return territory.overlay?.rx || 78;
  };

  overlayRy = (territory) => {
    return territory.overlay?.ry || 48;
  };

  territoryClass = (territoryKey) => {
    if (territoryKey === this.args.selectedFrom) {
      return "is-selected-from";
    }

    if (territoryKey === this.args.selectedTo) {
      return "is-selected-to";
    }

    if (
      this.args.selectedFrom &&
      (this.args.map.connections || []).some(
        (connection) =>
          [connection.from, connection.to].includes(this.args.selectedFrom) &&
          [connection.from, connection.to].includes(territoryKey)
      )
    ) {
      return "is-adjacent-to-selection";
    }

    return "";
  };

  @action
  selectTerritory(territoryKey) {
    this.args.onSelect?.(territoryKey);
  }

  @action
  handleMapClick(event) {
    if (event.target.closest("[data-territory-key]")) {
      return;
    }

    this.args.onClearSelection?.();
  }

  <template>
    <svg
      class="not-risk-map {{if @compact 'is-compact' 'is-large'}}"
      viewBox={{@map.view_box}}
      role="img"
      aria-label={{@map.name}}
      {{on "click" this.handleMapClick}}
    >
      <image
        class="not-risk-map-background"
        href={{@map.background_image_url}}
        x="0"
        y="0"
        width="1000"
        height="667"
        preserveAspectRatio="xMidYMid meet"
      />

      <g class="not-risk-map-ownership">
        {{#each @map.territories as |territory|}}
          <ellipse
            class="not-risk-territory-overlay {{this.territoryClass territory.key}}"
            cx={{this.overlayX territory}}
            cy={{this.overlayY territory}}
            rx={{this.overlayRx territory}}
            ry={{this.overlayRy territory}}
            fill={{this.fillFor territory.key}}
          />
        {{/each}}
      </g>

      <g class="not-risk-map-selected-connections">
        {{#each this.selectedConnections as |connection|}}
          {{#if connection.path}}
            <path d={{connection.path}} />
          {{else}}
            <line
              x1={{connection.x1}}
              y1={{connection.y1}}
              x2={{connection.x2}}
              y2={{connection.y2}}
            />
          {{/if}}
        {{/each}}
      </g>

      <g class="not-risk-map-hit-zones">
        {{#each @map.territories as |territory|}}
          <ellipse
            class="not-risk-map-label-hit-area {{this.territoryClass territory.key}}"
            data-territory-key={{territory.key}}
            cx={{this.overlayX territory}}
            cy={{this.overlayY territory}}
            rx={{this.overlayRx territory}}
            ry={{this.overlayRy territory}}
            {{on "click" (fn this.selectTerritory territory.key)}}
          />
        {{/each}}
      </g>

      <g class="not-risk-map-labels">
        {{#each @map.territories as |territory|}}
          <title>{{territory.name}} - {{this.ownerNameFor territory.key}} - {{this.armiesFor territory.key}} armies</title>
          <circle
            cx={{this.unitsX territory}}
            cy={{this.unitsY territory}}
            r="18"
            class="not-risk-map-army-disc"
            style={{this.armyDiscStyle territory.key}}
          />
          <text
            x={{this.labelX territory}}
            y={{this.labelY territory}}
            class="not-risk-map-label"
            text-anchor="middle"
          >{{territory.name}}</text>
          <text
            x={{this.unitsX territory}}
            y={{this.unitsY territory}}
            class="not-risk-map-armies"
            text-anchor="middle"
            dominant-baseline="middle"
          >{{this.armiesFor territory.key}}</text>
        {{/each}}
      </g>
    </svg>
  </template>
}
