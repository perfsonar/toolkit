#!/bin/bash
#
# upgrade_fix_cert_serial.sh
#    The 3.2 version of the toolkit would generate certificates with serial
#    number 0 which could cause warnings from browsers.

CERT="/etc/pki/tls/certs/localhost.crt"
if [ -e $CERT ]; then
    SERIAL=`openssl x509 -serial -noout -in $CERT | sed -e 's/serial=//'`
    if [ "$SERIAL" == "00" -o $SERIAL == "0" ]; then
        echo "Serial is 0. Regenerating."
        mv $CERT $CERT.back
        /sbin/service generate_cert_init_script start
    fi
fi
