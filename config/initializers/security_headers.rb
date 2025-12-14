# frozen_string_literal: true

# Security Headers Configuration
#
# Implements defense-in-depth security headers to protect against:
# - XSS (Cross-Site Scripting)
# - Clickjacking
# - MIME-sniffing attacks
# - Information leakage
# - Man-in-the-middle attacks
#
# Security Impact: Prevents multiple attack vectors (MEDIUM severity)

Rails.application.config.action_dispatch.default_headers.merge!({
                                                                  # X-Frame-Options: Prevent clickjacking attacks
                                                                  # DENY = page cannot be displayed in iframe/frame
                                                                  'X-Frame-Options' => 'DENY',

                                                                  # X-Content-Type-Options: Prevent MIME-sniffing
                                                                  # nosniff = browser must not override Content-Type
                                                                  'X-Content-Type-Options' => 'nosniff',

                                                                  # X-XSS-Protection: Legacy XSS protection (for older browsers)
                                                                  # 1; mode=block = enable XSS filter and block page rendering if attack detected
                                                                  'X-XSS-Protection' => '1; mode=block',

                                                                  # X-Download-Options: Prevent IE from executing downloads in site context
                                                                  'X-Download-Options' => 'noopen',

                                                                  # X-Permitted-Cross-Domain-Policies: Restrict Flash/PDF cross-domain requests
                                                                  'X-Permitted-Cross-Domain-Policies' => 'none',

                                                                  # Referrer-Policy: Control referrer information leakage
                                                                  # strict-origin-when-cross-origin = send origin only for cross-origin requests
                                                                  'Referrer-Policy' => 'strict-origin-when-cross-origin'
                                                                })

# Content Security Policy (CSP)
# Defense against XSS, code injection, and other code-based attacks
Rails.application.configure do
  config.content_security_policy do |policy|
    # Default: only allow resources from same origin
    policy.default_src :self, :https

    # Fonts: allow from self and data URIs (for icon fonts)
    policy.font_src :self, :https, :data

    # Images: allow from self, https, and data URIs
    policy.img_src :self, :https, :data, :blob

    # Objects: block all (no Flash, Java applets, etc.)
    policy.object_src :none

    # Scripts: allow from self and inline scripts with nonce
    # ActiveAdmin requires some inline scripts
    policy.script_src :self, :https, :unsafe_inline, :unsafe_eval

    # Styles: allow from self and inline styles with nonce
    # ActiveAdmin requires inline styles
    policy.style_src :self, :https, :unsafe_inline

    # Frames: allow from self (for ActiveAdmin embeds)
    policy.frame_src :self

    # Connections: allow AJAX requests to same origin
    policy.connect_src :self

    # Base URI: restrict base tag to same origin
    policy.base_uri :self

    # Form actions: only allow form submissions to same origin
    policy.form_action :self

    # Frame ancestors: prevent page from being framed (clickjacking)
    policy.frame_ancestors :none

    # Upgrade insecure requests (HTTP -> HTTPS)
    policy.upgrade_insecure_requests true if Rails.env.production?
  end

  # Generate session nonces for permitted inline scripts/styles
  # This allows specific inline code while blocking malicious injection
  config.content_security_policy_nonce_generator = lambda { |request|
    request.session.id.to_s
  }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # CSP is now enforced after validation
  # Set to true temporarily if debugging CSP violations
  config.content_security_policy_report_only = false
end

# Strict-Transport-Security (HSTS)
# Force HTTPS for all requests (production only)
if Rails.env.production?
  Rails.application.config.ssl_options = {
    hsts: {
      expires: 1.year,           # Cache for 1 year
      subdomains: true,          # Apply to all subdomains
      preload: true              # Allow browser preload lists
    }
  }
end

Rails.logger.info('Security headers configured')
