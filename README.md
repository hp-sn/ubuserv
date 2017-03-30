# ubuserv

Ubuserv provides the following services in a container:

DNS (bind)
DHCP (isc-dhcp-server)
Webserver (nginx - with fcgiwrap)
Network latency monitoring (smokeping)
Enabling the services on container creation can be controlled individually by the following environment variables:

DHCPD_ENABLED (default: false)

BIND_ENABLED (default:true)

NGINX_ENABLED (default:true)

SMOKEPING_ENABLED (default:true)

Based on the above variables, the image uses supervisord to control each of the processes.

Supervisor process names are as follows:

dhcpd

named

nginx

smokeping

Within a container, the processes can be reloaded/restarted/stopped by using the command suprvisorctl. Run "supervisorctl help" for help.

The image provides the ability to mount a volume at /data which will then enable persistent configs for all of the above mentioned processes.

For e.g. creating a container as follows will enable all the configuration information to be stored at /host/somefolder/myubuserv

docker create -v /host/somefolder/myubuserv:/data hpsn/ubuserv:latest

The above command will create the following dirs on "host" :

somefolder

|----- myubuserv

     |---------- bindconf

     |---------- dhcpdconf

     |----------  nginxconf

     |----------  smokepingconf
Within the container, symbolic links are created as follows:

/data/bindconf -------> /etc/bind

/data/dhcpdconf -------> /etc/dhcp

/data/nginxconf -------> /etc/nginx

/data/smokepingconf -------> /etc/smokeping

All services run on default ports, except nginx. The default http port on nginx has been changed to 8888.

Following probes are available with smokeping:

fping

echoping

speedtest-cli (https://github.com/mad-ady/smokeping-speedtest)

Enjoy !

Report any issues at https://github.com/hp-sn/ubuserv
