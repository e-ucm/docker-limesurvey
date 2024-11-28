FROM eucm/simplesamlphp:1.19.9-3

# Optimize recurrent builds by using a helper container runing apt-cache
ARG USE_APT_CACHE
ENV USE_APT_CACHE ${USE_APT_CACHE}
RUN ([ ! -z $USE_APT_CACHE ] && echo 'Acquire::http { Proxy "http://172.17.0.1:3142"; };' >> /etc/apt/apt.conf.d/01proxy \
    && echo 'Acquire::HTTPS::Proxy "false";' >> /etc/apt/apt.conf.d/01proxy) || true

# Install dependencies
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libc-client-dev \
        libfreetype6-dev \
        libmcrypt-dev \
        libjpeg-dev \
        libwebp-dev \
        libxpm-dev \
        libldap2-dev \
        zlib1g-dev \
        libkrb5-dev \
        libtidy-dev \
        libbz2-dev \
        libzip-dev \
        libsodium-dev \
    ; \
    \
    docker-php-ext-configure gd --with-freetype=/usr/include/  --with-jpeg=/usr --with-webp=/usr --with-xpm=/usr; \
    docker-php-ext-install gd; \
    docker-php-ext-install mysqli pdo pdo_mysql opcache bz2 zip iconv tidy; \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/; \ 
    docker-php-ext-install ldap; \ 
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos; \ 
    docker-php-ext-install imap; \
    docker-php-ext-install sodium; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN a2enmod rewrite

#Set PHP defaults for Limesurvey (allow bigger uploads)
RUN { \
        echo 'memory_limit=256M'; \
        echo 'upload_max_filesize=128M'; \
        echo 'post_max_size=128M'; \
        echo 'max_execution_time=120'; \
        echo 'max_input_vars=10000'; \
    } > /usr/local/etc/php/conf.d/uploads.ini

RUN { \
        echo 'date.timezone=Europe/Madrid'; \
    } > /usr/local/etc/php/conf.d/timezone.ini

ENV LIMESURVEY_VERSION 4.6.3+210518
ENV DOWNLOAD_URL https://github.com/LimeSurvey/LimeSurvey/archive/${LIMESURVEY_VERSION}.tar.gz
ENV DOWNLOAD_SHA256 3c59afc13d0cf974c465c5f851cb8837117518e94031f5e3a28ba468ad734ce2

RUN set -ex; \
    curl -SL "$DOWNLOAD_URL" -o /tmp/lime.tar.gz; \
    echo "$DOWNLOAD_SHA256 /tmp/lime.tar.gz" | sha256sum -c -; \
    tar xf /tmp/lime.tar.gz --strip-components=1 -C /var/www/html; \ 
    chown -R www-data:www-data /var/www/html; \
    rm -rf /tmp/* /var/tmp/*

COPY overlay /
RUN set -ex; \
    find /var/tmp/patches/limesurvey -type f -exec patch -p1 -i {} \;; \
    mkdir /etc/limesurvey;

ENV LIMESURVEY_AUTHSAML_VERSION 0.2.0
ENV LIMESURVEY_AUTHSAML_URL https://github.com/e-ucm/Limesurvey-SAML-Authentication/archive/${LIMESURVEY_AUTHSAML_VERSION}.tar.gz
ENV LIMESURVEY_AUTHSAML_SHA256 b3f42d01515d429a379d63ded074a32c83dbae35fa89f439551b140a43705456
RUN set -ex; \
    curl -SL "$LIMESURVEY_AUTHSAML_URL" -o /tmp/authsaml.tar.gz; \
    echo "$LIMESURVEY_AUTHSAML_SHA256 /tmp/authsaml.tar.gz" | sha256sum -c -; \
    mkdir /tmp/authsaml; \
    tar xf /tmp/authsaml.tar.gz --strip-components=1 -C /tmp/authsaml; \
    cp -r /tmp/authsaml/Limesurvey-SAML-Authentication/ /var/www/html/plugins/AuthSAML/; \
    chown -R www-data:www-data /var/www/html/plugins/AuthSAML; \
    rm -rf /tmp/* /var/tmp/*

RUN set -ex; \
    mkdir /usr/share/limesurvey; \
    cp -a /var/www/html/plugins /usr/share/limesurvey; \
    cp -a /var/www/html/upload /usr/share/limesurvey; \
    cp -a /var/www/html/tmp /usr/share/limesurvey;

VOLUME [ "/etc/limesurvey", "/var/www/html/plugins", "/var/www/html/upload", "/var/www/html/tmp" ]