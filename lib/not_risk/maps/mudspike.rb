# frozen_string_literal: true

module ::NotRisk
  module Maps
    module Mudspike
      KEY = "mudspike"

      TERRITORIES = [
        {
          key: "ashfen",
          name: "Ashfen Reach",
          path: "M70 72 C118 38 204 42 258 78 L266 168 C218 198 128 202 76 165 Z",
          label: [168, 121],
          adjacent: %w[brindlehook cinderwash frostmere],
        },
        {
          key: "brindlehook",
          name: "Brindlehook",
          path: "M315 78 C378 42 464 58 520 103 L492 185 C430 206 350 196 300 158 Z",
          label: [413, 125],
          adjacent: %w[ashfen cinderwash duskbarrow],
        },
        {
          key: "cinderwash",
          name: "Cinderwash Basin",
          path: "M82 225 C136 198 226 205 275 244 L260 350 C205 382 116 372 70 326 Z",
          label: [172, 291],
          scale: 0.74,
          adjacent: %w[ashfen brindlehook emberfall frostmere],
        },
        {
          key: "duskbarrow",
          name: "Duskbarrow",
          path: "M520 212 C585 172 680 170 742 212 L730 325 C670 354 568 350 505 310 Z",
          label: [623, 275],
          scale: 0.74,
          adjacent: %w[brindlehook emberfall galecrag ivyspine],
        },
        {
          key: "emberfall",
          name: "Emberfall March",
          path: "M310 224 C365 196 464 202 510 244 L490 350 C430 382 342 372 296 328 Z",
          label: [404, 290],
          adjacent: %w[cinderwash duskbarrow frostmere highmire],
        },
        {
          key: "frostmere",
          name: "Frostmere",
          path: "M92 405 C146 366 230 374 286 420 L270 525 C205 552 118 535 74 480 Z",
          label: [178, 465],
          adjacent: %w[ashfen cinderwash emberfall highmire],
        },
        {
          key: "galecrag",
          name: "Galecrag Peaks",
          path: "M700 95 C762 58 846 80 890 142 L864 265 C802 292 718 280 668 228 Z",
          label: [785, 180],
          adjacent: %w[duskbarrow ivyspine kobaltfjord],
        },
        {
          key: "highmire",
          name: "Highmire",
          path: "M320 395 C382 362 470 374 522 420 L492 525 C432 552 350 540 300 492 Z",
          label: [410, 465],
          adjacent: %w[emberfall frostmere ivyspine lanterncoast],
        },
        {
          key: "ivyspine",
          name: "Ivyspine Vale",
          path: "M555 382 C620 346 716 358 770 405 L748 518 C680 550 590 532 540 482 Z",
          label: [655, 456],
          scale: 0.74,
          adjacent: %w[duskbarrow galecrag highmire kobaltfjord],
        },
        {
          key: "kobaltfjord",
          name: "Kobaltfjord",
          path: "M775 325 C828 292 892 315 910 382 L874 500 C812 518 762 488 744 430 Z",
          label: [830, 417],
          scale: 0.72,
          adjacent: %w[galecrag ivyspine lanterncoast],
        },
        {
          key: "lanterncoast",
          name: "Lantern Coast",
          path: "M290 540 C354 512 444 520 500 560 L478 625 C408 642 325 632 270 598 Z",
          label: [385, 586],
          adjacent: %w[highmire kobaltfjord moonspire],
        },
        {
          key: "moonspire",
          name: "Moonspire Strand",
          path: "M540 540 C620 512 732 520 792 565 L770 625 C690 642 586 635 522 600 Z",
          label: [656, 586],
          adjacent: %w[lanterncoast],
        },
      ].freeze

      BY_KEY = TERRITORIES.index_by { |territory| territory[:key] }.freeze
      ROUTES = {
        %w[ashfen brindlehook] => "M266 122 C282 112 294 112 315 122",
        %w[ashfen cinderwash] => "M168 176 C155 190 150 205 154 224",
        %w[ashfen frostmere] => "M102 172 C38 280 42 392 104 438",
        %w[brindlehook cinderwash] => "M342 172 C286 185 226 205 196 230",
        %w[brindlehook duskbarrow] => "M486 154 C532 162 565 184 590 216",
        %w[cinderwash emberfall] => "M276 290 C286 280 298 278 310 286",
        %w[cinderwash frostmere] => "M166 364 C158 378 156 392 164 408",
        %w[emberfall duskbarrow] => "M510 286 C512 278 516 272 525 268",
        %w[emberfall frostmere] => "M350 348 C300 365 240 392 202 424",
        %w[emberfall highmire] => "M410 352 C418 365 420 378 416 395",
        %w[duskbarrow galecrag] => "M710 215 C722 195 744 184 766 178",
        %w[duskbarrow ivyspine] => "M640 328 C646 346 650 365 650 384",
        %w[galecrag ivyspine] => "M735 258 C705 298 680 340 666 382",
        %w[galecrag kobaltfjord] => "M842 266 C858 288 864 310 858 334",
        %w[frostmere highmire] => "M286 462 C298 454 308 454 320 462",
        %w[highmire ivyspine] => "M522 462 C532 450 542 448 555 456",
        %w[highmire lanterncoast] => "M414 522 C410 534 404 544 398 554",
        %w[ivyspine kobaltfjord] => "M768 438 C780 428 790 424 802 422",
        %w[kobaltfjord lanterncoast] => "M804 508 C752 620 566 640 430 610",
        %w[lanterncoast moonspire] => "M500 586 C512 578 526 578 540 586",
      }.transform_keys { |keys| keys.sort }.freeze
      CONNECTIONS =
        TERRITORIES
          .flat_map do |territory|
            territory[:adjacent].map do |adjacent_key|
              [territory[:key], adjacent_key].sort
            end
          end
          .uniq
          .sort
          .map do |from_key, to_key|
            from = BY_KEY[from_key]
            to = BY_KEY[to_key]

            {
              from: from_key,
              to: to_key,
              path: ROUTES.fetch([from_key, to_key].sort),
              x1: from[:label][0],
              y1: from[:label][1],
              x2: to[:label][0],
              y2: to[:label][1],
            }
          end
          .freeze

      RIVERS = [
        { key: "ashfen-creek", path: "M130 105 C160 112 188 108 220 130" },
        { key: "cinderwash-run", path: "M124 272 C160 260 200 268 232 306" },
        { key: "emberfall-brook", path: "M356 260 C392 272 430 268 462 318" },
        { key: "frostmere-rill", path: "M132 448 C164 430 205 438 244 482" },
        { key: "highmire-thread", path: "M358 448 C394 430 440 438 478 486" },
        { key: "ivyspine-river", path: "M600 430 C640 414 690 428 728 488" },
      ].freeze

      FEATURES = [
        { type: "marsh", x: 132, y: 132, scale: 0.85 },
        { type: "forest", x: 435, y: 112, scale: 0.82 },
        { type: "marsh", x: 146, y: 318, scale: 0.78 },
        { type: "ruin", x: 614, y: 252, scale: 0.85 },
        { type: "forest", x: 368, y: 312, scale: 0.75 },
        { type: "marsh", x: 202, y: 488, scale: 0.86 },
        { type: "mountain", x: 790, y: 150, scale: 1.05 },
        { type: "mountain", x: 426, y: 448, scale: 0.88 },
        { type: "forest", x: 672, y: 472, scale: 0.85 },
        { type: "mountain", x: 842, y: 392, scale: 0.75 },
        { type: "ruin", x: 350, y: 574, scale: 0.72 },
        { type: "forest", x: 705, y: 574, scale: 0.7 },
      ].freeze

      def self.territories
        TERRITORIES
      end

      def self.territory(key)
        BY_KEY[key.to_s]
      end

      def self.adjacent?(from_key, to_key)
        territory(from_key)&.dig(:adjacent)&.include?(to_key.to_s)
      end

      def self.serialized
        {
          key: KEY,
          name: "Mudspike Campaign",
          view_box: "0 0 920 640",
          territories: TERRITORIES,
          connections: CONNECTIONS,
          rivers: RIVERS,
          features: FEATURES,
        }
      end
    end
  end
end
