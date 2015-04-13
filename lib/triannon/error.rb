module Triannon
  # generic Triannon error allowing rescue to catch all Triannon exceptions
  class Error < RuntimeError
  end

  class ExternalReferenceError < Triannon::Error
    def initialize(message = nil)
      super(message)
    end
  end

  # used to keep HTTP response info from LDP
  class LDPStorageError < Triannon::Error
    attr_accessor :ldp_resp_status, :ldp_resp_body
    def initialize(message = nil, ldp_resp_status = nil, ldp_resp_body = nil)
      super(message)
      self.ldp_resp_status = ldp_resp_status if ldp_resp_status
      self.ldp_resp_body = ldp_resp_body if ldp_resp_body
    end
  end

  # used to keep HTTP response info from Solr
  class SearchError < Triannon::Error
    attr_accessor :search_resp_status, :search_resp_body
    def initialize(message = nil, search_resp_status = nil, search_resp_body = nil)
      super(message)
      self.search_resp_status = search_resp_status if search_resp_status
      self.search_resp_body = search_resp_body if search_resp_body
    end
  end

end
