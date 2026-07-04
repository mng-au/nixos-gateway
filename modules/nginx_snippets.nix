
let
  acme_domain = builtins.getEnv "ACME_DOMAIN";
in
{
  hsts = ''
   # Add HSTS header with preloading to HTTPS requests.
   # Adding this header to HTTP requests is discouraged
   map $scheme $hsts_header {
       https   "max-age=31536000; includeSubdomains; preload";
   }
   add_header Strict-Transport-Security $hsts_header;

   # Enable CSP for your services.
   #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

   # Minimize information leaked to other domains
   add_header 'Referrer-Policy' 'origin-when-cross-origin';

   # Disable embedding as a frame
   add_header X-Frame-Options DENY;

   # Prevent injection of code in other mime types (XSS Attacks)
   add_header X-Content-Type-Options nosniff;

   # This might create errors
   proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
 '';

  internal_only = ''
      deny   192.168.9.1;
      allow  127.0.0.1;
      allow  192.168.1.0/24;
      allow  192.168.8.0/22;
      allow  100.64.0.0/10;
      allow  192.168.240.0/20; # docker
      allow  172.0.0.0/8; # docker
      deny   all;
  '';

  authelia_location = ''
      set $upstream_authelia http://192.168.11.23:9091/api/verify;

      location /authelia {
        ## Essential Proxy Configuration
        internal;
        proxy_pass $upstream_authelia;

        ## Headers
        ## The headers starting with X-* are required.
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Original-Method $request_method;
        proxy_set_header X-Forwarded-Method $request_method;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Uri $request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_set_header Connection "";

        ## Basic Proxy Configuration
        proxy_pass_request_body off;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; # Timeout if the real server is dead
        proxy_redirect http:// $scheme://;
        proxy_http_version 1.1;
        proxy_cache_bypass $cookie_session;
        proxy_no_cache $cookie_session;
        proxy_buffers 4 32k;
        client_body_buffer_size 128k;

        ## Advanced Proxy Configuration
        send_timeout 5m;
        proxy_read_timeout 240;
        proxy_send_timeout 240;
        proxy_connect_timeout 240;
      }
  '';

  ## Send a subrequest to Authelia to verify if the user is authenticated and has permission to access the resource.
  authelia_authrequest = ''
      auth_request /authelia;

      ## Set the $target_url variable based on the original request.

      ## Comment this line if you're using nginx without the http_set_misc module.
      # set_escape_uri $target_url $scheme://$http_host$request_uri;

      ## Uncomment this line if you're using NGINX without the http_set_misc module.
      set $target_url $scheme://$http_host$request_uri;

      ## Save the upstream response headers from Authelia to variables.
      auth_request_set $user $upstream_http_remote_user;
      auth_request_set $groups $upstream_http_remote_groups;
      auth_request_set $name $upstream_http_remote_name;
      auth_request_set $email $upstream_http_remote_email;

      ## Inject the response headers from the variables into the request made to the backend.
      proxy_set_header Remote-User $user;
      proxy_set_header Remote-Groups $groups;
      proxy_set_header Remote-Name $name;
      proxy_set_header Remote-Email $email;

      ## If the subreqest returns 200 pass to the backend, if the subrequest returns 401 redirect to the portal.
      error_page 401 =302 https://auth.${acme_domain}/?rd=$target_url;
  '';
}
