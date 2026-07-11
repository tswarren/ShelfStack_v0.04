# frozen_string_literal: true

module Products
  class FieldLabelResolver
    PUBLISHER_LABELS = {
      "book" => "Publisher",
      "recorded_music" => "Label",
      "videorecording" => "Studio",
      "game" => "Publisher",
      "periodical" => "Publisher",
      "calendar" => "Publisher",
      "sideline" => "Publisher",
      "other" => "Publisher"
    }.freeze

    GENRE_LABELS = {
      "recorded_music" => "Genre",
      "videorecording" => "Genre",
      "game" => "Genre",
      "sideline" => "Sideline category",
      "calendar" => "Theme"
    }.freeze

    class << self
      def publisher_label(staff_item_kind)
        PUBLISHER_LABELS.fetch(staff_item_kind.to_s, "Publisher")
      end

      def genre_label(staff_item_kind)
        GENRE_LABELS.fetch(staff_item_kind.to_s, "Genre")
      end

      def labels_for(staff_item_kind:)
        {
          publisher: publisher_label(staff_item_kind),
          genre_scheme: genre_label(staff_item_kind),
          item_kind: ItemKindNormalizer.staff_label(staff_item_kind)
        }
      end
    end
  end
end
