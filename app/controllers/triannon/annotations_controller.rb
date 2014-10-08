require_dependency "triannon/application_controller"

module Triannon
  class AnnotationsController < ApplicationController
    before_action :default_format_jsonld, only: [:show]
    before_action :set_annotation, only: [:show, :edit, :update, :destroy]

    # GET /annotations/annotations
    def index
      @annotations = Annotation.all
    end

    # GET /annotations/annotations/1
    def show
      respond_to do |format|
        format.jsonld { render :json => @annotation.graph.to_jsonld, content_type: "application/ld+json" }
        format.ttl { render :body => @annotation.graph.to_ttl, content_type: request.accept if (request.accept && request.accept.is_a?(String)) } 
        format.rdfxml { render :body => @annotation.graph.to_rdfxml, content_type: request.accept if (request.accept && request.accept.is_a?(String)) } 
        format.json { render :json => @annotation.graph.to_jsonld, content_type: request.accept if (request.accept && request.accept.is_a?(String)) } 
        format.xml { render :xml => @annotation.graph.to_rdfxml, content_type: request.accept if (request.accept && request.accept.is_a?(String)) } 
        format.html { render :show }
      end
    end

    # GET /annotations/annotations/new
    def new
      @annotation = Annotation.new
    end

    # GET /annotations/annotations/1/edit
    def edit
    end

    # POST /annotations/annotations
    def create
      @annotation = Annotation.new(annotation_params)

      if @annotation.save
        redirect_to @annotation, notice: 'Annotation was successfully created.'
      else
        render :new
      end
    end

    # PATCH/PUT /annotations/annotations/1
    def update
      if @annotation.update(annotation_params)
        redirect_to @annotation, notice: 'Annotation was successfully updated.'
      else
        render :edit
      end
    end

    # DELETE /annotations/annotations/1
    def destroy
      @annotation.destroy
      redirect_to annotations_url, notice: 'Annotation was successfully destroyed.'
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_annotation
        @annotation = Annotation.find(params[:id])
      end

      # Only allow a trusted parameter "white list" through.
      def annotation_params
        params.require(:annotation).permit(:data)
      end
      
      def default_format_jsonld
        if ((!request.accept || request.accept.empty?) && (!params[:format] || params[:format].empty?))
          request.format = "jsonld"
        end
      end
  end
end
