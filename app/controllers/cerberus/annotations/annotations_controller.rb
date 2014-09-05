require 'shellwords'
module Cerberus::Annotations
  class AnnotationsController < ApplicationController
    def index
      @annotations = Dir.glob(File.join(fixtures_path, '*')).map { |x| x.split("/").last.gsub('.json', '') }
      
      respond_to do |format|
        format.html
      end
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
      @annotation = Annotation.from_json(File.read(File.join(fixtures_path, params[:id] + ".json")))
    end
    
    def fixtures_path
      File.join(Cerberus::Annotations::Engine.root, 'spec', 'fixtures', 'annotations')
    end
  end
end
