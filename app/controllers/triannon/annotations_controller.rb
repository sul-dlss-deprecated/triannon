require_dependency "triannon/application_controller"

module Triannon
  class AnnotationsController < ApplicationController
    include RdfResponseFormats

    rescue_from Triannon::LDPStorageError, with: :ldp_storage_error
    rescue_from Triannon::LDPContainerError, with: :ldp_container_error
    rescue_from Triannon::ExternalReferenceError, with: :ext_ref_error
    rescue_from Triannon::SearchError, with: :search_error
    before_action :default_format_jsonld, only: [:show]
    before_action :set_annotation, only: [:show, :update, :destroy]

    # GET /annotations
    def index
      if !params[:anno_root].blank?
        redirect_to "/#{params[:anno_root]}/search"
      else
        redirect_to "/search"
      end
    end

    # GET /annotations/1
    def show
      # TODO:  json.set! "@context", OA::Graph::OA_DATED_CONTEXT_URL - would this work?
      respond_to do |format|
        format.jsonld {
          context_url = context_url_from_accept ? context_url_from_accept : context_url_from_link
          if context_url && context_url == OA::Graph::IIIF_CONTEXT_URL
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
          if context_url && context_url == OA::Graph::IIIF_CONTEXT_URL
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
          @annotation = Annotation.new({:data => params["annotation"]["data"], :root_container => params[:anno_root]})
        end
      else
        # it's a direct post request
        content_type = request.headers["Content-Type"]
        @annotation = Annotation.new({:data => request.body.read, :expected_content_type => content_type, :root_container => params[:anno_root]})
      end

      if @annotation.save
        default_format_jsonld # NOTE: this must be here and not in before_filter or we get Missing template errors
        flash[:notice] = "Annotation #{@annotation.id} was successfully created."
        respond_to do |format|
          format.jsonld {
            context_url = context_url_from_link ? context_url_from_link : context_url_from_accept
            if context_url && context_url == OA::Graph::IIIF_CONTEXT_URL
              render :json => @annotation.jsonld_iiif, status: 201, content_type: "application/ld+json"
            else
              render :json => @annotation.jsonld_oa, status: 201, content_type: "application/ld+json"
            end
          }
          format.ttl {
            accept_return_type = mime_type_from_accept(["application/x-turtle", "text/turtle"])
            render :body => @annotation.graph.to_ttl, status: 201, content_type: accept_return_type if accept_return_type }
          format.rdfxml {
            accept_return_type = mime_type_from_accept(["application/rdf+xml", "text/rdf+xml", "text/rdf"])
            render :body => @annotation.graph.to_rdfxml, status: 201, content_type: accept_return_type if accept_return_type }
          format.json {
            accept_return_type = mime_type_from_accept(["application/json", "text/x-json", "application/jsonrequest"])
            context_url = context_url_from_link ? context_url_from_link : context_url_from_accept
            if context_url && context_url == OA::Graph::IIIF_CONTEXT_URL
              render :json => @annotation.jsonld_iiif, status: 201, content_type: accept_return_type if accept_return_type
            else
              render :json => @annotation.jsonld_oa, status: 201, content_type: accept_return_type if accept_return_type
            end
          }
          format.xml {
            accept_return_type = mime_type_from_accept(["application/xml", "text/xml", "application/x-xml"])
            render :body => @annotation.graph.to_rdfxml, status: 201, content_type: accept_return_type if accept_return_type }
          format.html { redirect_to "/annotations/#{params[:anno_root]}/#{@annotation.id}" }
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
      redirect_to "/annotations/#{params[:anno_root]}", status: 204, notice: 'Annotation was successfully destroyed.'
    end

private

    def set_annotation
      @annotation = Annotation.find(params[:id], params[:anno_root])
    end

    # render Triannon::ExternalReferenceError
    def ext_ref_error(err)
      render plain: err.message, status: 403
    end

    # render Triannon::LDPContainer error
    def ldp_container_error(err)
      render :plain => err.message, status: 403
    end

    # render Triannon::LDPStorage error
    def ldp_storage_error(err)
      render :body => "<h2>#{err.message}</h2>" + err.ldp_resp_body, status: err.ldp_resp_status, content_type: "text/html"
    end

    # render Triannon::SearchError
    def search_error(err)
      render :body => "<h2>#{err.message}</h2>" + (err.search_resp_body ? err.search_resp_body : ""),
        status: err.search_resp_status ? err.search_resp_status : 400,
        content_type: "text/html"
    end

    # render json_ld respecting requested context
    # @param [String] req_context set to "iiif" or "oa".  Default is oa
    # @param [String] mime_type the mime type to be set in the Content-Type header of the HTTP response
    def render_jsonld_per_context(req_context, mime_type = nil)
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
