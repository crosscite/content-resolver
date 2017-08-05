module Helpable
  extend ActiveSupport::Concern

  require "bolognese"
  require "maremma"

  included do
    include Bolognese::DoiUtils
    include Bolognese::Utils

    def get_handle_url(id: nil)
      response = Maremma.head(id, limit: 0)
      response.headers["location"]
    end

    # content-types registered for that DOI
    def get_registered_content_types(id)
      doi = doi_from_url(id)
      media_url = ENV['SEARCH_URL'] + "api?q=doi:#{doi}&fl=doi,media&wt=json"
      response = Maremma.get media_url
      doc = response.body.dig("data", "response", "docs").first
      if doc.present?
        doc.fetch("media", []).reduce({}) do|sum, i|
          content_type, url = i.split(":", 2)
          sum[content_type] = url
          sum
        end.to_h
      else
        {}
      end
    end

    def available_content_types
      content_types = Mime::LOOKUP.map { |k, v| [k, v.to_sym] }.to_h
      content_types.except("text/html", "application/xhtml+xml", "text/plain", "application/json", "text/x-json", "application/jsonrequest")
    end
  end
end
