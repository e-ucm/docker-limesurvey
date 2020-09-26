FROM eucm/simplesamlphp:1.18.8-4

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
        libpng-dev \
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
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/  --with-png-dir=/usr --with-jpeg-dir=/usr --with-webp-dir=/usr --with-xpm-dir=/usr; \
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

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini


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

ENV LIMESURVEY_VERSION 4.3.15+200907
ENV DOWNLOAD_URL https://github.com/LimeSurvey/LimeSurvey/archive/${LIMESURVEY_VERSION}.tar.gz
ENV DOWNLOAD_SHA256 46fbdf7ab3760c64ecd145b97e24be7705f1deebeb67c9e7b58a55ed106b73a2

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

ENV LIMESURVEY_AUTHSAML_VERSION 0.1.0
ENV LIMESURVEY_AUTHSAML_URL https://github.com/e-ucm/Limesurvey-SAML-Authentication/archive/${LIMESURVEY_AUTHSAML_VERSION}.tar.gz
ENV LIMESURVEY_AUTHSAML_SHA256 e7991e0872251d15dca8e6638cde3a48a1013b1a1c61877ef7df41a5c5ab8bd1
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

VOLUME ["/etc/limesurvey"]
VOLUME ["/var/www/html/plugins"]
VOLUME ["/var/www/html/upload"]
VOLUME ["/var/www/html/tmp"]