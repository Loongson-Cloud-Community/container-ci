#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:

FROM rabbitmq:4.2.6

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

ENV RABBITMQADMIN_VERSION 2.29.0
RUN set -eux; \
        url="https://github.com/loongarch64-releases/rabbitmqadmin-ng/releases/download/v$RABBITMQADMIN_VERSION/rabbitmqadmin-$RABBITMQADMIN_VERSION-loongarch64-unknown-linux-gnu"; \
        apt-get update; \
        apt-get install -y --no-install-recommends ca-certificates wget; \
	wget -O /usr/local/bin/rabbitmqadmin "$url"; \
	chmod +x /usr/local/bin/rabbitmqadmin; \
	rabbitmqadmin --help

EXPOSE 15671 15672
