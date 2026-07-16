# discourse-not-risk

A small Discourse plugin that adds a forum-native, turn-based, Risk-inspired strategy game using a fictional test campaign map.

This is an MVP. It intentionally does not include cards, objectives, teams, AI players, fog of war, or a polished admin UI.

If people use it or like the idea I might add some more things (like an Admin UI and settings), plus of course feel free to fork and add away yourself.

## Screenshot

Main game map

![Not Risk game board screenshot](docs/Screenshot1.jpg)

Battles!

![Battle screenshot](docs/battle-dialog.jpg)

## Creating a game

Admins can configure one or more categories in the `not_risk_game_categories` plugin setting. Members who have Discourse permission to create topics in one of those categories will see a **New Game** button there. The form creates the campaign topic, enrolls its creator, and opens the War Room.

Other members can join from the War Room until the campaign reaches four players. The creator or a staff member can start once 2–4 players have joined.

The existing staff workflow remains available. Create a normal Discourse topic, then use the browser console helper below or call the JSON endpoint with that topic ID:

```bash
curl -X POST http://localhost:3000/not-risk/games.json \
  -H "Content-Type: application/json" \
  -d '{"topic_id":123,"name":"Turn Based Test Campaign"}'
```
(or use the browser script helper below)

The endpoint creates a game and appends this placeholder to the first post:

```text
[not-risk game=123]
```

The cooked post renders a compact campaign summary. Use **Open War Room** to play at:

```text
/not-risk/games/123
```

## MVP flow

1. A member creates a campaign in a configured category and is joined automatically, or staff attaches one to an existing topic.
2. Other players join from the War Room, or staff adds players with `POST /not-risk/games/:id/join`.
3. The creator or staff starts the game once 2–4 players have joined.
4. Before Turn 1, every player deploys their territory-count base allowance without bonuses; attacks remain disabled until everyone finishes.
5. On normal turns, the current player deploys a base of 3 armies for 1–3 territories, 4 for 4–8, or 5 for 9+, then adds territory bonuses.
6. Current player may attack adjacent enemy territories repeatedly.
7. Current player advances to fortify, then may fortify once between adjacent owned territories.
8. Current player ends the turn.
9. The plugin creates one topic reply summarizing the completed turn.

All committed actions are stored in `not_risk_events`.

New campaigns record rules version **v0.4** and show it beside the Battle Log heading. Each turn also records the reinforcement calculation used for that player.

Help and Rules can be found in game. Territory bonuses are currently: Central Kingdom +1, Southern Bay +1, and Isle of Mists +1. Starting ownership is randomized, but these bonus territories are dealt across players first so one player cannot start with all three.

## Map assets

The MVP uses a raster-backed test Fantasy 12 map. The base art is served from:

```text
/plugins/discourse-not-risk/images/fantasy-12-small.jpg
```

Territory labels, army badges, ownership tint, selection state, and hit zones are SVG overlays driven by `lib/not_risk/maps/fantasy_12_risklike.json`. If you have local development games created with an older map key, recreate them after updating the plugin.

The current campaign supports 2–4 players. Larger maps and player counts can be added later.

## API

```text
GET    /not-risk/games/:id
POST   /not-risk/games
POST   /not-risk/games/:id/join
POST   /not-risk/games/:id/start
POST   /not-risk/games/:id/deploy
POST   /not-risk/games/:id/attack
POST   /not-risk/games/:id/advance_to_fortify
POST   /not-risk/games/:id/fortify
POST   /not-risk/games/:id/end_turn
```

## Tests

Run from the Discourse checkout after linking the plugin:

```bash
bundle exec rspec plugins/discourse-not-risk/spec
```

For a narrower backend pass:

```bash
bundle exec rspec \
  plugins/discourse-not-risk/spec/services/not_risk_game_engine_spec.rb \
  plugins/discourse-not-risk/spec/requests/not_risk_games_controller_spec.rb \
  plugins/discourse-not-risk/spec/lib/not_risk_pretty_text_spec.rb
```

## Staff Browser Helpers

If signed in as a Staff group member then you can browser console this:

```jscript
const csrf = document.querySelector("meta[name=csrf-token]").content;

async function nr(path, body = {}) {
  const res = await fetch(`/not-risk${path}.json`, {
    method: "POST",
    credentials: "same-origin",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": csrf,
    },
    body: JSON.stringify(body),
  });

  const text = await res.text();
  const json = JSON.parse(text);
  console.log(json);
  return json;
}
```

```jscript
// Create the game replacing TOPIC_ID with the integer of the one you made e.g. /c/gaming/8 would be '8'.
const game = await nr("/games", {
  topic_id: TOPIC_ID,
  name: "Board Game Test Campaign",
});
```

```jscript
// Join existing forum members to the new game using their ids, replace ALICE_ID and BOB_ID below
// /u/username.json should give back id e.g. "users" "id"
await nr(`/games/${game.game.id}/join`, { user_id: ALICE_ID });
await nr(`/games/${game.game.id}/join`, { user_id: BOB_ID });
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
