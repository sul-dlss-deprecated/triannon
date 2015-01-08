require_dependency "triannon/application_controller"

module Triannon
  class AnnotationsController < ApplicationController
    before_action :default_format_jsonld, only: [:show]
    before_action :set_annotation, only: [:show, :edit, :update, :destroy]
    rescue_from Triannon::ExternalReferenceError, with: :ext_ref_error

    # GET /annotations/annotations
    def index
      @annotations = Annotation.all
    end

    # GET /annotations/annotations/1
    def show
      respond_to do |format|
        format.jsonld { render_jsonld_per_context (params[:jsonld_context]) }
        format.ttl {
          accept_return_type = mime_type_from_accept(["application/x-turtle", "text/turtle"])
          render :body => @annotation.graph.to_ttl, content_type: accept_return_type if accept_return_type }
        format.rdfxml {
          accept_return_type = mime_type_from_accept(["application/rdf+xml", "text/rdf+xml", "text/rdf"])
          render :body => @annotation.graph.to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.json {
          accept_return_type = mime_type_from_accept(["application/json", "text/x-json", "application/jsonrequest"])
          render_jsonld_per_context(params[:jsonld_context], accept_return_type) }
        format.xml {
          accept_return_type = mime_type_from_accept(["application/xml", "text/xml", "application/x-xml"])
          render :xml => @annotation.graph.to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.html { render :show }
      end
    end

    # GET /annotations/annotations/new
    def new
      @annotation = Annotation.new
    end

    # NOT YET IMPLEMENTED
    # GET /annotations/annotations/1/edit    
#    def edit
#    end

    # POST /annotations/annotations
    def create
      # FIXME: this is probably a bad way of allowing app form to be used as well as direct post requests
      if params["annotation"]
        # it's from app html form
        params.require(:annotation).permit(:data)
        if params["annotation"]["data"]
          @annotation = Annotation.new({:data => params["annotation"]["data"]})
        end
      else
        # it's a direct post request
        @annotation = Annotation.new(:data => request.body.read)
      end
      
      if @annotation.save
        redirect_to @annotation, status: 201, notice: 'Annotation was successfully created.'
      else
        render :new
      end
    end

    # NOT YET IMPLEMENTED
    # PATCH/PUT /annotations/annotations/1
#    def update
#      if @annotation.update(params)
#        redirect_to @annotation, notice: 'Annotation was successfully updated.'
#      else
#        render :edit
#      end
#    end

    # DELETE /annotations/annotations/1
    def destroy
      @annotation.destroy
      redirect_to annotations_url, status: 204, notice: 'Annotation was successfully destroyed.'
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_annotation
        @annotation = Annotation.find(params[:id])
      end
      
      def default_format_jsonld
        if ((!request.accept || request.accept.empty?) && (!params[:format] || params[:format].empty?))
          request.format = "jsonld"
        end
      end

      # find first mime type from request.accept that matches return mime type
      def mime_type_from_accept(return_mime_types)
        @mime_type_from_accept ||= begin
          if request.accept && request.accept.is_a?(String)
            accepted_formats = request.accept.split(',')
            accepted_formats.each { |accepted_format|
              if return_mime_types.include? accepted_format
                return accepted_format
              end
            }
          end
        end
      end

      # handle Triannon::ExternalReferenceError
      def ext_ref_error(exception)
        render plain: exception.message, status: 403
      end
      
      # render json_ld respecting requested context
      # @param [String] req_context set to "iiif" or "oa".  Default is OA
      # @param [String] mime_type the mime type to be set in the Content-Type header of the HTTP response
      def render_jsonld_per_context (req_context, mime_type=nil)
        case req_context
          when "iiif", "IIIF"
            if mime_type
              render :json => @annotation.jsonld_iiif, content_type: mime_type
            else
              render :json => @annotation.jsonld_iiif
            end
          when "oa", "OA"
            if mime_type
              render :json => @annotation.jsonld_oa, content_type: mime_type
            else
              render :json => @annotation.jsonld_oa
            end
          else
            if mime_type
              render :json => @annotation.jsonld_oa, content_type: mime_type
            else
              render :json => @annotation.jsonld_oa
            end
        end 
      end
  end
end
