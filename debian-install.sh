#!/bin/sh

test `id -u` -ne 0 && exec sudo $0

apt-get install curl libdata-dump-perl cups printer-driver-fujixerox cups-ipp-utils printer-driver-cups-pdf snmp snmp-mibs-downloader

# enable mibs
grep -i '^mibs :' /etc/snmp/snmp.conf && perl -p -i -n -e 's/^mibs :.*/mibs +ALL/' /etc/snmp/snmp.conf
