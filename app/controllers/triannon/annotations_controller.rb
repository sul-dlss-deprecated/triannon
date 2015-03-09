require_dependency "triannon/application_controller"

module Triannon
  class AnnotationsController < ApplicationController
    before_action :default_format_jsonld, only: [:show]
    before_action :set_annotation, only: [:show, :update, :destroy]
    rescue_from Triannon::ExternalReferenceError, with: :ext_ref_error

    # GET /annotations
    def index
      @annotations = Annotation.all
    end

    # GET /annotations/1
    def show
      # TODO:  json.set! "@context", Triannon::JsonldContext::OA_DATED_CONTEXT_URL - would this work?
      respond_to do |format|
        format.jsonld {
          context_url = context_url_from_accept ? context_url_from_accept : context_url_from_link
          if context_url && context_url == Triannon::JsonldContext::IIIF_CONTEXT_URL
            render_jsonld_per_context("iiif", "application/ld+json")
          else
            render_jsonld_per_context(params[:jsonld_context], "application/ld+json")
          end
        }
        format.ttl {
          accept_return_type = mime_type_from_accept(["application/x-turtle", "text/turtle"])
          render :body => @annotation.graph.to_ttl, content_type: accept_return_type if accept_return_type }
        format.rdfxml {
          accept_return_type = mime_type_from_accept(["application/rdf+xml", "text/rdf+xml", "text/rdf"])
          render :body => @annotation.graph.to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.json {
          accept_return_type = mime_type_from_accept(["application/json", "text/x-json", "application/jsonrequest"])
          context_url = context_url_from_link ? context_url_from_link : context_url_from_accept
          if context_url && context_url == Triannon::JsonldContext::IIIF_CONTEXT_URL
            render_jsonld_per_context("iiif", accept_return_type)
          else
            render_jsonld_per_context(params[:jsonld_context], accept_return_type)
          end
        }
        format.xml {
          accept_return_type = mime_type_from_accept(["application/xml", "text/xml", "application/x-xml"])
          render :xml => @annotation.graph.to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.html { render :show }
      end
    end

    # GET /annotations/new
    def new
      @annotation = Annotation.new
    end

    # NOT YET IMPLEMENTED
    # GET /annotations/1/edit    
#    def edit
#    end

    # POST /annotations
    def create
      # FIXME: this is probably a bad way of allowing app form to be used as well as direct post requests
      # see https://github.com/sul-dlss/triannon/issues/90 -- prob just want to fix the form to do a POST
      #  note that need to check for empty? if HTTP Header Content-Type is json (but not jsonld).
      if params["annotation"] && !params["annotation"].empty?
        # it's from app html form
        params.require(:annotation).permit(:data)
        if params["annotation"]["data"]
          @annotation = Annotation.new({:data => params["annotation"]["data"]})
        end
      else
        # it's a direct post request
        content_type = request.headers["Content-Type"]
        @annotation = Annotation.new({:data => request.body.read, :expected_content_type => content_type})
      end
      
      if @annotation.save
        default_format_jsonld # NOTE: this must be here and not in before_filter or we get Missing template errors
        respond_to do |format|
          format.jsonld {
            context_url = context_url_from_link ? context_url_from_link : context_url_from_accept
            if context_url && context_url == Triannon::JsonldContext::IIIF_CONTEXT_URL
              render :json => @annotation.jsonld_iiif, status: 201, content_type: "application/ld+json", notice: "Annotation #{@annotation.id} was successfully created."
            else
              render :json => @annotation.jsonld_oa, status: 201, content_type: "application/ld+json", notice: "Annotation #{@annotation.id} was successfully created."
            end
          }
          format.ttl {
            accept_return_type = mime_type_from_accept(["application/x-turtle", "text/turtle"])
            render :body => @annotation.graph.to_ttl, status: 201, notice: "Annotation #{@annotation.id} was successfully created.", content_type: accept_return_type if accept_return_type }
          format.rdfxml {
            accept_return_type = mime_type_from_accept(["application/rdf+xml", "text/rdf+xml", "text/rdf"])
            render :body => @annotation.graph.to_rdfxml, status: 201, notice: "Annotation #{@annotation.id} was successfully created.", content_type: accept_return_type if accept_return_type }
          format.json {
            accept_return_type = mime_type_from_accept(["application/json", "text/x-json", "application/jsonrequest"])
            context_url = context_url_from_link ? context_url_from_link : context_url_from_accept
            if context_url && context_url == Triannon::JsonldContext::IIIF_CONTEXT_URL
              render :json => @annotation.jsonld_iiif, status: 201, notice: "Annotation #{@annotation.id} was successfully created.", content_type: accept_return_type if accept_return_type
            else
              render :json => @annotation.jsonld_oa, status: 201, notice: "Annotation #{@annotation.id} was successfully created.", content_type: accept_return_type if accept_return_type
            end
          }
          format.xml {
            accept_return_type = mime_type_from_accept(["application/xml", "text/xml", "application/x-xml"])
            render :body => @annotation.graph.to_rdfxml, status: 201, notice: "Annotation #{@annotation.id} was successfully created.", content_type: accept_return_type if accept_return_type }
          format.html { render :show, location: @annotation, status: 201, content_type: "text/html", notice: "Annotation #{@annotation.id} was successfully created." }
        end
      else
        render :new, status: 400
      end
    end

    # NOT YET IMPLEMENTED
    # PATCH/PUT /annotations/1
#    def update
#      if @annotation.update(params)
#        redirect_to @annotation, notice: 'Annotation was successfully updated.'
#      else
#        render :edit
#      end
#    end

    # DELETE /annotations/1
    def destroy
      @annotation.destroy
      redirect_to annotations_url, status: 204, notice: 'Annotation was successfully destroyed.'
    end
    
private

    def set_annotation
      @annotation = Annotation.find(params[:id])
    end
    
    # set format to jsonld if it isn't already set
    def default_format_jsonld
      if ((!request.accept || request.accept.empty?) && (!params[:format] || params[:format].empty?))
        request.format = "jsonld"
      end
    end

    # find first mime type from request.accept that matches return mime type
    def mime_type_from_accept(return_mime_types)
      @mime_type_from_accept ||= begin
        if request.accept && request.accept.is_a?(String)
          accept_mime_types = request.accept.split(',')
          accept_mime_types.each { |mime_type|
            mime_str = mime_type.split("; profile=").first.strip
            if return_mime_types.include? mime_str
              return mime_str
            end
          }
        end
      end
    end

    # parse the Accept HTTP header for the value of profile if it is a request for jsonld or json
    # e.g. Accept: application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"
    # @return [String] url for jsonld @context or nil if missing or non-jsonld/json format
    def context_url_from_accept
      if request.format == "jsonld" || request.format == "json"
        accept_str = request.accept
        if accept_str && accept_str.split("profile=") && accept_str.split("profile=").last
          context_url = accept_str.split("profile=").last.strip
          context_url = context_url[1, context_url.size] if context_url.start_with?('"')
          context_url = context_url[0, context_url.size-1] if context_url.end_with?('"')
          case context_url
            when Triannon::JsonldContext::OA_DATED_CONTEXT_URL, 
              Triannon::JsonldContext::OA_CONTEXT_URL,
              Triannon::JsonldContext::IIIF_CONTEXT_URL
              context_url
            else
              nil
          end
        end
      end
    end

    # parse the Accept HTTP Link for the value of rel if it is a request for jsonld or json
    # e.g. Link: http://www.w3.org/ns/oa.json; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"
    # note that the "type" part is optional
    # @return [String] url for jsonld @context or nil if missing or non-jsonld/json format
    def context_url_from_link
      if request.format == "jsonld" || request.format == "json"
        link_str = request.headers["Link"]
        if link_str && link_str.split("; rel=") && link_str.split("; rel=").first
          context_url = link_str.split("; rel=").first.strip
          case context_url
            when Triannon::JsonldContext::OA_DATED_CONTEXT_URL,
              Triannon::JsonldContext::OA_CONTEXT_URL,
              Triannon::JsonldContext::IIIF_CONTEXT_URL
              context_url
            else
              nil
          end
        end
      end
    end

    # handle Triannon::ExternalReferenceError
    def ext_ref_error(exception)
      render plain: exception.message, status: 403
    end
    
    # render json_ld respecting requested context
    # @param [String] req_context set to "iiif" or "oa".  Default is oa
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

  end # class AnnotationsController
end # module Triannon
