FROM martialblog/limesurvey:6.13.2-250506-apache

COPY patches /patches

RUN for p in /patches/*.patch; do \
      echo "Applying $p"; \
      patch -p0 -d /var/www/html < "$p"; \
    done