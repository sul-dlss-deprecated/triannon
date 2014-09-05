require 'shellwords'
module Cerberus::Annotations
  class AnnotationsController < ApplicationController
    def index
      render text: 'ok'
    end
    
    def show
      load_annotation
      
      respond_to do |format|
        format.html
        format.json
      end
    end
    
    private
    def load_annotation
      @annotation = Annotation.from_json(File.read(File.join(Cerberus::Annotations::Engine.root, 'spec', 'fixtures', 'annotations', params[:id] + ".json")))
    end
  end
end
