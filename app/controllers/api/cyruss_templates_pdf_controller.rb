# frozen_string_literal: true

# CYRUSS extension to Docuseal (open source, AGPL-3.0).
#
# POST /api/templates/pdf : creates a template from a PDF sent in base64,
# with its fields placed by coordinates. Same contract as the route of the
# same name in Docuseal Pro / cloud, so the CYRUSS server works with both:
#
#   { "name": "Bail", "external_id": "...",
#     "documents": [{ "name": "Bail", "file": "<base64>",
#                     "fields": [{ "name": "Signature Locataire", "type": "signature",
#                                  "role": "Locataire", "required": true,
#                                  (optional) "readonly": true, "default_value": "{{date}}" = signing date,
#                                  "areas": [{ "page": 1, "x": 0.1, "y": 0.8, "w": 0.3, "h": 0.06 }] }] }] }
#
# Pages are 1-based in the request (as in the Docuseal API docs), 0-based
# inside Docuseal. x, y, w, h are fractions of the page, origin top left.
# The signers are then invited with the standard open source route
# POST /api/templates/:id/submissions (send_email: false).
module Api
  class CyrussTemplatesPdfController < ApiBaseController
    MAX_PDF_BYTES = 20.megabytes
    FIELD_TYPES = %w[signature initials date text checkbox].freeze

    def create
      authorize!(:create, Template)

      documents = Array.wrap(params[:documents])
      return render(json: { error: 'documents is required' }, status: :unprocessable_content) if documents.empty?

      pdfs = documents.map { |doc| Base64.decode64(doc[:file].to_s.sub(/\Adata:[^;]+;base64,/, '')) }
      bad = pdfs.index { |data| !data.start_with?('%PDF-') || data.bytesize > MAX_PDF_BYTES }
      if bad
        return render(json: { error: "documents[#{bad}].file must be a PDF of #{MAX_PDF_BYTES / 1.megabyte} MB at most" },
                      status: :unprocessable_content)
      end

      template = Template.new(account: current_account, author: current_user,
                              name: params[:name].presence || 'Document',
                              external_id: params[:external_id].presence, source: 'api')
      template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
      Templates.maybe_assign_access(template)
      template.save!

      roles = {}
      schema = []
      fields = []

      documents.each_with_index do |doc, index|
        data = pdfs[index]
        name = (doc[:name].presence || "Document #{index + 1}").to_s.tr('/', '-')
        tempfile = Tempfile.new(['cyruss', '.pdf'])
        tempfile.binmode
        tempfile.write(data)
        tempfile.rewind
        file = ActionDispatch::Http::UploadedFile.new(filename: "#{name}.pdf", type: 'application/pdf', tempfile:)

        attachment = Templates::CreateAttachments.handle_pdf_or_image(template, file, data, {}, extract_fields: false)
        schema << { 'attachment_uuid' => attachment.uuid, 'name' => name }

        Array.wrap(doc[:fields]).each do |field|
          role = field[:role].presence || 'First Party'
          roles[role] ||= { 'name' => role, 'uuid' => SecureRandom.uuid }
          type = FIELD_TYPES.include?(field[:type].to_s) ? field[:type].to_s : 'signature'

          fields << {
            'uuid' => SecureRandom.uuid,
            'submitter_uuid' => roles[role]['uuid'],
            'name' => field[:name].to_s,
            'type' => type,
            'required' => field[:required] != false,
            'readonly' => field[:readonly] == true,
            'default_value' => field[:default_value].is_a?(String) ? field[:default_value] : nil,
            'preferences' => field[:preferences].respond_to?(:to_unsafe_h) ? field[:preferences].to_unsafe_h : {},
            'areas' => Array.wrap(field[:areas]).map do |area|
              {
                'attachment_uuid' => attachment.uuid,
                'page' => [area[:page].to_i - 1, 0].max,
                'x' => area[:x].to_f, 'y' => area[:y].to_f, 'w' => area[:w].to_f, 'h' => area[:h].to_f
              }
            end
          }.compact
        end
      ensure
        tempfile&.close!
      end

      template.update!(schema:, fields:, submitters: roles.values)

      WebhookUrls.enqueue_events(template, 'template.created')

      render json: Templates::SerializeForApi.call(template.reload)
    rescue Templates::CreateAttachments::PdfEncrypted
      render json: { error: 'PDF is password protected' }, status: :unprocessable_content
    end
  end
end
