# cyruss-docuseal

Docuseal (open source, AGPL-3.0) with one addition for CYRUSS: the route
`POST /api/templates/pdf`, which creates a template from a PDF sent in
base64, with signature and date fields placed by coordinates. Docuseal
offers this route only in its paid versions (Pro / cloud); the CYRUSS server
uses it to send the lease to sign. Same contract as the paid route, so the
server works with both.

What is added (nothing else is changed):

- `app/controllers/api/cyruss_templates_pdf_controller.rb`
- `config/initializers/cyruss_templates_pdf.rb` (the route)

## Install (API server)

1. DNS: `sign.cyruss.ai` to the server.
2. `docker compose up -d --build` (Docuseal listens on 127.0.0.1:3005).
3. Reverse proxy: `sign.cyruss.ai` to `127.0.0.1:3005`.
4. Open https://sign.cyruss.ai once: create the admin account, then
   Settings > API: copy the API key; Settings > Webhooks: add
   `https://api.cyruss.ai/v1/esign/webhook/docuseal` and copy its secret.
5. CYRUSS server `.env`: `ESIGN_PROVIDER=docuseal`,
   `DOCUSEAL_URL=https://sign.cyruss.ai`, `DOCUSEAL_API_URL=http://127.0.0.1:3005`,
   `DOCUSEAL_API_KEY`, `DOCUSEAL_WEBHOOK_SECRET`, `ESIGN_TEST_MODE=true` until
   the legal review (D104), then `false`.

## Before changing the Docuseal version

The extension uses `Templates::CreateAttachments.handle_pdf_or_image`,
`Templates::SerializeForApi` and the template `schema` / `fields` /
`submitters` format of 3.3.2. Test the route again after any upgrade.

## Licence

AGPL-3.0, like Docuseal (see LICENSE). Because the signing pages are used
over the network, the source of this modified version must stay available
to its users: this repository is public for that reason.
Additional term (LICENSE_ADDITIONAL_TERMS): the « Propulsé par DocuSeal »
attribution must stay visible on the signing pages. We do not remove it.
