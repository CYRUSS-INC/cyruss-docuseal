# Docuseal (open source) + the CYRUSS route POST /api/templates/pdf.
# Pinned version: check the extension again before changing it.
FROM docuseal/docuseal:3.3.2
COPY app/controllers/api/cyruss_templates_pdf_controller.rb /app/app/controllers/api/
COPY config/initializers/cyruss_templates_pdf.rb /app/config/initializers/
