ARG PHP_EXTENSIONS="intl"

FROM thecodingmachine/php:8.2-v4-fpm as php

ENV PHP_EXTENSION_INTL=1

COPY --from=composer:2.5.8 --chown=docker:docker /usr/bin/composer /usr/bin/composer

WORKDIR /application

FROM nginx:1.25.1-alpine AS nginx
