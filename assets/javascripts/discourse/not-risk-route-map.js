export default function () {
  this.route("not-risk", { path: "/not-risk" }, function () {
    this.route("game", { path: "/games/:game_id" });
  });
}
