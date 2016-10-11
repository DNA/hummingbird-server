class ListImport
  class AnimePlanet
    class Row
      attr_reader :node, :type

      def initialize(node, type)
        @node = node
        @type = type
      end

      def media
        key = "#{type}/#{media_info[:id]}"

        Mapping.lookup('animeplanet', key) ||
          Mapping.guess(type.classify.safe_constantize, media_info)
      end

      def media_info
        {
          id: node.attr('data-id')&.to_i,
          title: media_title(tooltip),
          show_type: show_type(tooltip),
          episode_count: total_episodes(tooltip),
          chapter_count: total_chapters(tooltip)
        }.compact
      end

      def status
        @status ||= media_status(tooltip)

        case @status
        when /ing\z/ then :current
        when /\AWant/ then :planned
        when /\AWon't/ then nil
        when 'Stalled' then :on_hold
        when 'Dropped' then :dropped
        when 'Watched', /Read([0-9.]+)?/ then :completed
        end
      end

      def progress
        if status == :completed
          if type == 'anime'
            media_info[:episode_count]
          else
            media_info[:chapter_count]
          end
        else
          media_progress(tooltip)
        end
      end

      def rating
        tooltip.css('.ttRating')&.last&.text&.to_f
      end

      def reconsume_count
        return unless type == 'anime' && status == :completed

        amount = tooltip.at_css('.myListBar')&.content
        amount&.split('-')&.last&.split('x')&.first&.to_i
      end

      def volumes
        return unless type == 'manga'

        if status == :completed
          total_volumes(tooltip)
        else
          read_volumes(tooltip)
        end
      end

      def data
        %i[status progress rating reconsume_count volumes].map { |k|
          [k, send(k)]
        }.to_h
      end

      private

      def tooltip
        @tooltip ||= Nokogiri::HTML.fragment(
          node.at_css('.tooltip').attr('title')
        )
      end

      # Media Info
      def media_title(fragment)
        fragment.at_css('h5')&.text
      end

      def show_type(fragment)
        return if type == 'manga'

        episodes = fragment.at_css('.entryBar .type').text

        episodes&.split(' (').first.strip
      end

      def total_episodes(fragment)
        return if type == 'manga'

        episodes = fragment.at_css('.entryBar .type').text

        episodes.match(/\d+/)[0].to_i
        # episodes&.split(' (')&.last&.gsub(/(ep?s)+/, '')&.to_i
      end

      def total_chapters(fragment)
        return if type == 'anime'

        chapters = fragment.at_css('.entryBar .iconVol').text

        chapters.match(/Ch:(\s\d+)/)[1].to_i
      rescue NameError
        # regex returned nil
        0
      end

      def total_volumes(fragment)
        total = fragment.at_css('.entryBar .iconVol').text

        total.match(/Vol:(\s\d+)/)[1].to_i
      end

      # Status
      def media_status(fragment)
        status = fragment.at_css('.myListBar').xpath('./text()').to_s.strip

        return status unless status.include?('-')

        status.split('-').first.strip
      end

      # Progress
      def media_progress(fragment)
        amount = fragment.at_css('.myListBar').xpath('./text()').to_s.strip

        return 0 if amount.exclude?('-') || amount.include?('vols')

        if type == 'anime'
          amount.split('-').last.split('/').first.to_i
        else
          amount.split('-').last.split(' ').first.to_i
        end
      end

      # Volumes
      def read_volumes(fragment)
        amount = fragment.at_css('.myListBar').xpath('./text()').to_s.strip

        return 0 if amount.exclude?('-') || amount.include?('chs')

        amount.split('-').last.split(' ').first.to_i
      end
    end
  end
end
