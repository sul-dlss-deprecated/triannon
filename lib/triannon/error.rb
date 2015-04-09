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
    attr_accessor :resp_status, :resp_body
    def initialize(message = nil, resp_status = nil, resp_body = nil)
      super(message)
      self.resp_status = resp_status if resp_status
      self.resp_body = resp_body if resp_body
    end
  end

end
