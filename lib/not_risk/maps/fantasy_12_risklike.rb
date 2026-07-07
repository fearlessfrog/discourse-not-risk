# frozen_string_literal: true

require "json"

module ::NotRisk
  module Maps
    module Fantasy12Risklike
      DATA = JSON.parse(File.read(File.expand_path("fantasy_12_risklike.json", __dir__)), symbolize_names: true)
      KEY = DATA.dig(:map, :key)
      NAME = "Fantasy 12 Campaign"
      BACKGROUND_IMAGE_URL = "/plugins/discourse-not-risk/images/fantasy-12-small.png"
      OVERLAY_DEFAULT = { rx: 78, ry: 48 }.freeze
      OVERLAYS = {
        central_kingdom: { rx: 100, ry: 66 },
        golden_plains: { rx: 92, ry: 54 },
        sand_realm: { rx: 88, ry: 56 },
        dark_marsh: { rx: 84, ry: 52 },
        southern_bay: { rx: 88, ry: 50 },
        isle_of_mists: { rx: 74, ry: 52 },
      }.freeze

      TERRITORIES =
        DATA[:territories]
          .map do |territory|
            key = territory[:id].to_s
            label = territory[:label]
            units = territory[:units]
            overlay = OVERLAY_DEFAULT.merge(OVERLAYS[key.to_sym] || {})

            {
              key: key,
              name: territory[:name],
              group: territory[:group],
              label: [label[:x], label[:y]],
              units: [units[:x], units[:y]],
              overlay: { cx: label[:x], cy: ((label[:y] + units[:y]) / 2.0).round, **overlay },
              adjacent: territory[:adjacent].map(&:to_s),
            }
          end
          .freeze
      BY_KEY = TERRITORIES.index_by { |territory| territory[:key] }.freeze
      ROUTES = {}.freeze
      CONNECTIONS =
        TERRITORIES
          .flat_map { |territory| territory[:adjacent].map { |adjacent_key| [territory[:key], adjacent_key].sort } }
          .uniq
          .sort
          .map do |from_key, to_key|
            from = BY_KEY[from_key]
            to = BY_KEY[to_key]

            {
              from: from_key,
              to: to_key,
              path: ROUTES[[from_key, to_key].sort],
              x1: from[:units][0],
              y1: from[:units][1],
              x2: to[:units][0],
              y2: to[:units][1],
            }
          end
          .freeze
      GROUPS = DATA[:groups].freeze

      def self.territories
        TERRITORIES
      end

      def self.territory(key)
        BY_KEY[key.to_s]
      end

      def self.adjacent?(from_key, to_key)
        from_key = from_key.to_s
        to_key = to_key.to_s

        territory(from_key)&.dig(:adjacent)&.include?(to_key) || territory(to_key)&.dig(:adjacent)&.include?(from_key)
      end

      def self.serialized
        view_box = DATA.dig(:map, :viewBox)

        {
          key: KEY,
          name: NAME,
          image_size: DATA.dig(:map, :imageSize),
          view_box: "0 0 #{view_box[:width]} #{view_box[:height]}",
          background_image_url: BACKGROUND_IMAGE_URL,
          territories: TERRITORIES,
          connections: CONNECTIONS,
          groups: GROUPS,
        }
      end
    end
  end
end
