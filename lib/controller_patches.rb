# -*- encoding : utf-8 -*-
# Add a callback - to be executed before each request in development,
# and at startup in production - to patch existing app classes.
# Doing so in init/environment.rb wouldn't work in development, since
# classes are reloaded, but initialization is not run each time.
# See http://stackoverflow.com/questions/7072758/plugin-not-reloading-in-development-mode
#
Rails.configuration.to_prepare do
  # Front page needs some additional info
  GeneralController.class_eval do

    def frontpage
      blog_cache("latest_blog_posts")
    end

    private

    def blog_cache(cache_key, expires=4.hours)
      # set @blog_items to an empty array and return if there's no blog feed
      if AlaveteliConfiguration::blog_feed.empty?
        @blog_items = []
        return
      end
      # nothing to do here, call the blog code and return
      return get_blog_content unless AlaveteliConfiguration::cache_fragments

      # read in the last timestamp
      updated = read_fragment("#{cache_key}-lastupdated")

      # construct the fragment key
      @fragment_key = "#{cache_key}-#{updated}"

      # if the fragment is unreadable or has reached expiry
      # attempt to pull in the blog feed
      if updated.nil? || !fragment_exist?(@fragment_key) ||
         Time.now > (Time.parse(updated) + expires)
        # keep a note of the old key
        old_key = @fragment_key.dup

        # prepare a new timestamp and fragment key
        updated = create_timestamp
        @fragment_key = "#{cache_key}-#{updated}"

        logger.info "attempting to pull in the feed"
        get_blog_content

        if @blog_items.empty?
          # attempt to write the previous fragment to our new cache
          fragment = read_fragment(old_key)
          if fragment
            logger.warn "Writing old blog fragment (#{old_key}) to " \
                        "current cache (#{@fragment_key}) due to feed " \
                        "error or timeout."
            write_fragment(@fragment_key, fragment)
          end
        end

        # store the new timestamp
        write_fragment("#{cache_key}-lastupdated", updated)
      end
    end

  end
end
