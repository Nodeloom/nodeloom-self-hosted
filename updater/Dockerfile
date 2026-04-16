FROM docker:27-cli

RUN apk add --no-cache jq bash

COPY update.sh /app/update.sh
RUN chmod +x /app/update.sh

WORKDIR /app

ENTRYPOINT ["/app/update.sh"]
