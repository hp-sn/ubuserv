#!/usr/bin/env bash
#===============================================================================
#          FILE: ubuserv.sh
#
#         USAGE: ./ubuserv.sh
#
#   DESCRIPTION: Entrypoint for ubuserv docker container
#        AUTHOR: Harman Nagra (harman@hpsn.info)
#================================================================================

set -o nounset
set -e

TZ=${TZ:-Etc/GMT}
DATA_DIR=${DATA_DIR:-/data}
DHCPD_ENABLED=${DHCPD_ENABLED:-""}
SMOKEPING_ENABLED=${SMOKEPING_ENABLED:-""}
BIND_ENABLED=${BIND_ENABLED:-""}
NGINX_ENABLED=${NGINX_ENABLED:-""}


############ Set Timezone ########################################

timezone() { local TZ="${1:-Etc/GMT}"
    [[ -e /usr/share/zoneinfo/$timezone ]] || {
        echo "ERROR: invalid timezone specified: $TZ" >&2
        return
    }

    if [[ -w /etc/timezone && $(cat /etc/timezone) != $TZ ]]; then
        echo "$TZ" >/etc/timezone
        ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
    fi
}

########### End Timezone ###########################################


# move DHCP conf dir to data volume

if [ ! -d $DATA_DIR/dhcpconf ]; then
	cp -R /etc/dhcp $DATA_DIR/dhcpconf \
	&& rm -fr /etc/dhcp \
	&& ln -s $DATA_DIR/dhcpconf /etc/dhcp
else
	rm -fr /etc/dhcp \
	&& ln -s $DATA_DIR/dhcpconf /etc/dhcp
fi

if [ ! -f $DATA_DIR/dhcpconf/dhcpd.leases ]; then
        touch $DATA_DIR/dhcpconf/dhcpd.leases
fi

# move BIND conf dir to data volume

if [ ! -d $DATA_DIR/bindconf ]; then
  cp -R /etc/bind $DATA_DIR/bindconf \
  && rm -fr /etc/bind \
  && ln -s $DATA_DIR/bindconf /etc/bind \
  && chown -R bind:bind $DATA_DIR/bindconf
else
  rm -fr /etc/bind \
  && ln -s $DATA_DIR/bindconf /etc/bind \
  && chown -R bind:bind $DATA_DIR/bindconf
fi

# move NGINX conf dir to data volume

if [ ! -d $DATA_DIR/nginxconf ]; then
  mkdir -p $DATA_DIR/nginxconf
fi

if [ ! -f $DATA_DIR/nginxconf/nginx.conf ]; then
  cp /etc/nginx/nginx.conf $DATA_DIR/nginxconf/nginx.conf \
  && rm -f /etc/nginx/nginx.conf \
  && ln -sf $DATA_DIR/nginxconf/nginx.conf /etc/nginx/nginx.conf
else
  rm -f /etc/nginx/nginx.conf \
  && ln -sf $DATA_DIR/nginxconf/nginx.conf /etc/nginx/nginx.conf
fi

if [ ! -f $DATA_DIR/nginxconf/sites-available/default ]; then
  cp -R /etc/nginx/sites-available $DATA_DIR/nginxconf/sites-available \
  && rm -f /etc/nginx/sites-enabled/default \
  && ln -sf $DATA_DIR/nginxconf/sites-available/default /etc/nginx/sites-enabled/default
else
  rm -f /etc/nginx/sites-enabled/default \
  && ln -sf $DATA_DIR/nginxconf/sites-available/default /etc/nginx/sites-enabled/default
fi

cp /usr/share/doc/fcgiwrap/examples/nginx.conf /etc/nginx/fcgiwrap.conf

if ! grep -Fxq "8888" $DATA_DIR/nginxconf/sites-available/default; then
  sed -i -e 's/80/8888/g' $DATA_DIR/nginxconf/sites-available/default
fi

if ! grep -Fxq "include /etc/nginx/fcgiwrap.conf;" $DATA_DIR/nginxconf/sites-available/default; then
  sed -i '/server\_name \_\;/a include /etc/nginx/fcgiwrap.conf\;' $DATA_DIR/nginxconf/sites-available/default
fi

if ! grep -Fxq "include /nginx-confs/smokeping.include;" $DATA_DIR/nginxconf/sites-available/default; then
  sed -i '/server\_name \_\;/a include /nginx-confs/smokeping.include\;' $DATA_DIR/nginxconf/sites-available/default
fi


# move SMOKEPING conf dir to data volume for persistence

if [ ! -d $DATA_DIR/smokepingconf ]; then
  cp -R /etc/smokeping $DATA_DIR/smokepingconf \
  && rm -fr /etc/smokeping \
  && ln -s $DATA_DIR/smokepingconf /etc/smokeping \
  && chown smokeping:smokeping $DATA_DIR/smokepingconf/smokeping_secrets
else
  rm -fr /etc/smokeping \
  && ln -s $DATA_DIR/smokepingconf /etc/smokeping \
  && chown smokeping:smokeping $DATA_DIR/smokepingconf/smokeping_secrets
fi

if [ ! -d /var/www/html/smokeping ]; then
  ln -s /usr/share/smokeping/www  /var/www/html/smokeping
fi

ln -sf /usr/lib/cgi-bin/smokeping.cgi /usr/share/smokeping/www/smokeping.cgi


########## Enable Services ########################################


if [ "${SMOKEPING_ENABLED}" == "true" ]; then
	mkdir -p /var/run/smokeping
  ln -sf /supervisor-confs/supervisor-smokeping.conf /etc/supervisor/conf.d/supervisor-smokeping.conf
fi


if [ "${NGINX_ENABLED}" == "true" ]; then
	ln -sf /supervisor-confs/supervisor-nginx.conf /etc/supervisor/conf.d/supervisor-nginx.conf
	ln -sf /supervisor-confs/supervisor-fcgiwrap.conf /etc/supervisor/conf.d/supervisor-fcgiwrap.conf
fi

if [ "${BIND_ENABLED}" == "true" ]; then
  ln -sf /supervisor-confs/supervisor-bind.conf /etc/supervisor/conf.d/supervisor-bind.conf
fi

if [ "${DHCPD_ENABLED}" == "true" ]; then
  ln -sf /supervisor-confs/supervisor-dhcpd.conf /etc/supervisor/conf.d/supervisor-dhcpd.conf
fi

# remove dhcpd pid file in case of improper shutdown
rm -fr /var/run/dhcpd.pid

exec $(which supervisord) -n -c /etc/supervisor/supervisord.conf
