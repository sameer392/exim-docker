FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV DOMAIN=hemochrom.com
ENV HOSTNAME=smtp0.hemochrom.com

# Install Exim4 and required packages (Dovecot is now a separate service)
RUN apt-get update && apt-get install -y --no-install-recommends \
    exim4 \
    sasl2-bin \
    libsasl2-modules \
    libsasl2-modules-sql \
    opendkim \
    opendkim-tools \
    openssl \
    supervisor \
    netcat-openbsd \
    tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create necessary directories
RUN mkdir -p /var/spool/exim4/input /var/spool/exim4/db /var/log/exim4 /etc/exim4 /var/mail/vhosts/${DOMAIN} \
    && chown -R Debian-exim:Debian-exim /var/spool/exim4 \
    && chmod 755 /var/spool/exim4 \
    && chmod 700 /var/spool/exim4/input \
    && chown -R Debian-exim:adm /var/log/exim4 \
    && chmod 755 /var/log/exim4 \
    && touch /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog \
    && chown Debian-exim:adm /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog \
    && chmod 640 /var/log/exim4/mainlog /var/log/exim4/rejectlog /var/log/exim4/paniclog

# Copy configuration files
COPY exim/update-exim4.conf.conf /etc/exim4/update-exim4.conf.conf
COPY exim/exim4.conf /etc/exim4/exim4.conf.template
COPY scripts/entrypoint-exim.sh /entrypoint.sh
COPY scripts/setup-exim-config.sh /scripts/setup-exim-config.sh
COPY scripts/setup-mail.sh /scripts/setup-mail.sh
COPY scripts/setup-dkim.sh /scripts/setup-dkim.sh
COPY scripts/render-exim-config.sh /scripts/render-exim-config.sh
COPY supervisord/supervisord-exim.conf /etc/supervisor/conf.d/supervisord.conf
COPY opendkim/opendkim.conf /etc/opendkim.conf
COPY opendkim/opendkim-KeyTable /etc/opendkim/KeyTable
COPY opendkim/opendkim-SigningTable /etc/opendkim/SigningTable
COPY opendkim/opendkim-TrustedHosts /etc/opendkim/TrustedHosts

# Setup DKIM
RUN mkdir -p /etc/opendkim/keys/${DOMAIN} \
    && chown -R opendkim:opendkim /etc/opendkim

RUN chmod +x /entrypoint.sh /scripts/setup-exim-config.sh /scripts/setup-mail.sh /scripts/setup-dkim.sh /scripts/render-exim-config.sh \
    && mkdir -p /var/log/supervisor

EXPOSE 25 587 465

CMD ["/entrypoint.sh"]
