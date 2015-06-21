backend server {
    .host = "127.0.0.1";
    .port = "80";
}

sub vcl_recv {
    # First call our identify_device subroutine to detect the device
    call identify_device;
    set req.grace = 1h;

    if (req.http.Accept-Encoding) {
    #revisit this list
        if (req.url ~ "\.(gif|jpg|jpeg|swf|flv|mp3|mp4|pdf|ico|png|gz|tgz|bz2)(\?.*|)$") {
            remove req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            remove req.http.Accept-Encoding;
        }
    }

    # Do not cache these paths.
    if (req.url ~ "^/not-cachable-page" ||
            req.url ~ "^/payment-page" ||
            req.url ~ "^/fully-dynamic-page") {
        return (pass);
    }


    if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
        unset req.http.cookie;
        set req.url = regsub(req.url, "\?.*$", "");
    }
    if (req.url ~ "\?(utm_(campaign|medium|source|term)|adParams|client|cx|eid|fbid|feed|ref(id|src)?|v(er|iew))=") {
        set req.url = regsub(req.url, "\?.*$", "");
    }
    if (req.http.cookie) {
        unset req.http.cookie;
    }


}

sub identify_device {
  # Default to thinking it's a PC
  set req.http.X-Device = "pc";

  if (req.http.User-Agent ~ "iPad" ) {
    # It says its a iPad - so let's give them the tablet-site
    set req.http.X-Device = "mobile-tablet";
  }


	elsif (req.http.User-Agent ~ "iP(hone|od)" || req.http.User-Agent ~ "Android" ) {
    # It says its a iPhone, iPod or Android - so let's give them the touch-site..
    set req.http.X-Device = "mobile-smart";
  }

  elsif (req.http.User-Agent ~ "SymbianOS" || req.http.User-Agent ~ "^BlackBerry" || req.http.User-Agent ~ "^SonyEricsson" || req.http.User-Agent ~ "^Nokia" || req.http.User-Agent ~ "^SAMSUNG" || req.http.User-Agent ~ "^LG") {
    # Some other sort of mobile
    set req.http.X-Device = "mobile-other";
  }
}

sub vcl_hash {
# Your existing hash-routine here..

    # Add the Device Type Mobile/Desktop in the hash key.
    #hash_data(req.http.X-Mobile-Device);
    #hash_data(req.http.X-Any-Server-Header-or-cookie-like-user-id-for-user-specific-data);
}

sub vcl_fetch {

    if ( req.request == "GET" ) {
        unset beresp.http.set-cookie;
        set beresp.ttl = 1h;
    }
    if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
        set beresp.ttl = 30d;
    }
}

sub vcl_deliver {
# multi-server webfarm? set a variable here so you can check
# the headers to see which frontend served the request
   set resp.http.X-Server = "server-01";

## For debugging cache hits	
   if (obj.hits > 0) {
     set resp.http.X-Cache = "HIT";
   } else {
     set resp.http.X-Cache = "MISS";
   }

}
sub vcl_hit {

}

sub vcl_miss {

}

# In the event of an error, show friendlier messages.
sub vcl_error {
# Redirect to some other URL in the case of a homepage failure.
#if (req.url ~ "^/?$") {
#  set obj.status = 302;
#  set obj.http.Location = "http://backup.example.com/";
#}

# Otherwise redirect to the homepage, which will likely be in the cache.
    set obj.http.Content-Type = "text/html; charset=utf-8";
    synthetic {"
        <html>
            <head>
            <title>Temporarily Down</title>
            <style>
            body { background: #303030; text-align: center; color: white; }
#page { border: 1px solid #CCC; width: 500px; margin: 100px auto 0; padding: 30px; background: #323232; }
        a, a:link, a:visited { color: #CCC; }
        .error { color: #222; }
        </style>
            </head>
            <body onload="setTimeout(function() { window.location = '/' }, 10000)">
            <div id="page">
            <h1 class="title">Server Down.</h1>
            <p>Meanwhile, We're redirecting you to the <a href="/">homepage</a>.</p>
            <!--div class="error">(Error "} + obj.status + " " + obj.response + {")</div-->
            </div>
            </body>
            </html>
            "};
        return (deliver);
}
