#!/bin/bash
# set -x
# https://help.ui.com/hc/en-us/articles/115015971688-EdgeRouter-OpenVPN-Server#1

export CATOP="./demoCA"
export DIRMODE=0777
export openssl="openssl"

export CAREQ="careq.pem"
export CAKEY="cakey.pem"
export CACERT="cacert.pem"

export NEWKEY="newkey.pem";
export NEWREQ="newreq.pem";
export NEWCERT="newcert.pem";

export DAYS="-days 365"
export CADAYS="-days 1095"	# 3 years

export countryName="US"
export stateOrProvinceName="New York"
export localityName="New York"
export organizationName="Ubiquiti"
export organizationalUnitName="Support"
export emailAddress="support@ui.com"
export clientlist="client1 client2"
export secret="secret"
export OPENSSL_CONFIG=""
source .env
export REQ="$openssl req -newkey rsa:2048 $OPENSSL_CONFIG"
export CA="$openssl ca $OPENSSL_CONFIG"
mkdir -m $DIRMODE /config/auth;

mkdir -m $DIRMODE ${CATOP};
mkdir -m $DIRMODE "${CATOP}/certs"
mkdir -m $DIRMODE "${CATOP}/crl"
mkdir -m $DIRMODE "${CATOP}/newcerts"
mkdir -m $DIRMODE "${CATOP}/private" 
touch ${CATOP}/index.txt
touch ${CATOP}/index.txt.attr
echo  "01" >${CATOP}/crlnumber
generateDh(){
        echo "3. Generate a Diffie-Hellman (DH) key file and place it in the /config/auth directory."
        openssl dhparam -out /config/auth/dh.pem -2 2048
}
generateRootCa(){
        # -subj "/C=$countryName/ST=$stateOrProvinceName/L=$localityName/O=$organizationName/OU=$organizationalUnitName/emailAddress=$emailAddress/CN=$commonName"
        echo "5. Generate a root certificate (replace <secret> with your desired passphrase)."

        export commonName="root"
        $REQ -new -keyout ${CATOP}/private/$CAKEY -out ${CATOP}/$CAREQ -subj "/countryName=$countryName/stateOrProvinceName=$stateOrProvinceName/localityName=$localityName/organizationName=$organizationName/organizationalUnitName=$organizationalUnitName/emailAddress=$emailAddress/commonName=$commonName" -passout env:secret || exit 1
        $CA -create_serial  -out ${CATOP}/$CACERT $CADAYS -batch -keyfile ${CATOP}/private/$CAKEY -passin env:secret -selfsign -extensions v3_ca  -infiles ${CATOP}/$CAREQ || exit 1

        echo "6. Copy the newly created certificate + key to the /config/auth directory."
        cp demoCA/cacert.pem /config/auth
        cp demoCA/private/cakey.pem /config/auth
}

generateServerKey(){
        echo "7. Generate the server certificate."
        export commonName="server"
        $REQ -new -keyout $NEWKEY -out $NEWREQ -subj "/countryName=$countryName/stateOrProvinceName=$stateOrProvinceName/localityName=$localityName/organizationName=$organizationName/organizationalUnitName=$organizationalUnitName/emailAddress=$emailAddress/commonName=$commonName" $DAYS -passout env:secret

        echo " 8. Sign the server certificate."
        $CA -policy policy_anything -passin env:secret -out $NEWCERT -infiles $NEWREQ || exit 1

        echo " 9. Move and rename the server certificate and key files to the /config/auth directory."
        mv newcert.pem /config/auth/server.pem
        mv newkey.pem /config/auth/server.key
        echo " 12. Remove the password from the server key file and optionally the client key file(s)."
        openssl rsa  -in /config/auth/server.key -out /config/auth/server-no-pass.key -passin env:secret || exit 1
        mv /config/auth/server-no-pass.key /config/auth/server.key 
        rm newreq.pem
}

generateClientKeys(){
        echo " 10. Generate, sign and move the certificate and key files for the first OpenVPN client."
        echo " 11. Repeat the process for the second OpenVPN client."

        for commonName in $clientlist; do
                $REQ -new -keyout $NEWKEY -passout env:secret -out $NEWREQ -subj "/countryName=$countryName/stateOrProvinceName=$stateOrProvinceName/localityName=$localityName/organizationName=$organizationName/organizationalUnitName=$organizationalUnitName/emailAddress=$emailAddress/commonName=$commonName" $DAYS || exit 1
                $CA -policy policy_anything -passin env:secret -out $NEWCERT -infiles $NEWREQ || exit 1
                mv newcert.pem /config/auth/${commonName}.pem
                mv newkey.pem /config/auth/${commonName}.key
                rm newreq.pem
        done
}

removePasswordFromClientKeys(){
        for commonName in $clientlist; do
                openssl rsa -in /config/auth/${commonName}.key -out /config/auth/${commonName}-no-pass.key -passin env:secret || exit 1
                mv /config/auth/${commonName}-no-pass.key /config/auth/${commonName}.key || exit 1
                chmod 644 /config/auth/${commonName}.key
        done 
}

generateDh
generateRootCa
generateServerKey
generateClientKeys
removePasswordFromClientKeys
