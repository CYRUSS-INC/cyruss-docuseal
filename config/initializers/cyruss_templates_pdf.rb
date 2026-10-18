# frozen_string_literal: true

# CYRUSS extension: POST /api/templates/pdf (see the controller).
Rails.application.routes.prepend do
  post '/api/templates/pdf', to: 'api/cyruss_templates_pdf#create', defaults: { format: :json }
end
