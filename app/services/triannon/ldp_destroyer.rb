
module Triannon

  class LdpDestroyer

    def self.destroy key
      conn = Faraday.new Triannon.config[:ldp_url]

      resp = conn.delete { |req| req.url key }
      if resp.status != 204
        raise "Unable to delete Annotation: #{key}\nResponse Status: #{resp.status}\nResponse Body: #{resp.body}"
      end
    end
  end
end
