module Triannon

  class AnnotationLdpMapper


    def self.ldp_to_annotation ldp_anno
      mapper = Triannon::AnnotationLdpMapper.new ldp_anno
      oa_anno = mapper.ldp_to_annotation
      oa_anno
    end

    def l_to_a

    end

  end

end