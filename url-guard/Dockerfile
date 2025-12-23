FROM docker:cli
RUN apk add --no-cache curl
COPY url-guard.sh /usr/local/bin/url-guard.sh
RUN chmod +x /usr/local/bin/url-guard.sh
ENTRYPOINT ["/usr/local/bin/url-guard.sh"]
