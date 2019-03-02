sudo apt-get install cups printer-driver-fujixerox cups-ipp-utils printer-driver-cups-pdf snmp snmp-mibs-downloader

# enable mibs
grep -i '^mibs :' /etc/snmp/snmp.conf && perl -p -i -n -e 's/^mibs : .*/mibs +ALL/' /etc/snmp/snmp.conf
