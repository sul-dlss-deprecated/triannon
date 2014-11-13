module Triannon
  # generic Triannon error allowing rescue to catch all Triannon exceptions
  class Error < RuntimeError
  end
  
  class ExternalReferenceError < Triannon::Error
  end
  
end
