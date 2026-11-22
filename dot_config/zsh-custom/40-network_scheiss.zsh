# Create this bundle by combining a suitable root certificate bundle with the zscaler root certificate
#
# Using brew, probably this bundle exists:
#    openssl storeutl -noout -text -certs /opt/homebrew/etc/ca-certificates/cert.pem
# From zscaler, probably this certificate exists:
#    openssl storeutl -noout -text -certs ~/.zcli/zscaler_root.pem
#
# Alternatively, locate in OSX Keychain, export zscaler as pem (System) and all certs into single pem (System roots)
#
# Brew bundle has post-install hook that adds Keychain system roots to the bundle.
# System roots might already has been provisioned so it's possible ca-certificates is already
# completed with zscaler root cert. To verify:
#
#   openssl storeutl -noout -text /opt/homebrew/etc/ca-certificates/cert.pem 2>/dev/null | grep -A2 "Zscaler"
#
# To trigger re-creation of the ca-certificates bundle, either:
#
#   brew reinstall ca-certificates
#   brew postinstall ca-certificates
#
# Grabbing the zscaler CA from OS trust store
#
#   security find-certificate -c "Zscaler Root CA" -p /Library/Keychains/System.keychain > ~/.zscaler/zscaler-ca.pem
#
# Concat pems into single bundle (if needed):
#
#   cat /opt/homebrew/etc/ca-certificates/cert.pem ~/.zscaler/zscaler-ca.pem > ~/.zscaler/bundle_combined.pem
#
# Else, simply copy ca-certificates bundle to the combined bundle location:
#
#   cp /opt/homebrew/etc/ca-certificates/cert.pem ~/.zscaler/bundle
#
ZSCALER_COMBINED_BUNDLE=~/.zscaler/bundle_combined.pem

# Java ignores the PEM bundle: it needs a keystore. Built from the combined bundle (which holds
# the full root set plus Zscaler), so one file serves every JDK. Rebuild after the bundle changes:
#   zscaler_java_truststore_build
ZSCALER_JAVA_TRUSTSTORE=~/.zscaler/java-truststore.p12
ZSCALER_JAVA_TRUSTSTORE_PASS=changeit   # Java convention, not a secret

# Source this file,then call below function in bashrc/zshrc and the likes
zscaler_bundle_on() {
  export AWS_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
  export CURL_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
  export HEX_CACERTS_PATH=$ZSCALER_COMBINED_BUNDLE
  export NODE_EXTRA_CA_CERTS=$ZSCALER_COMBINED_BUNDLE
  export PIP_CERT=$ZSCALER_COMBINED_BUNDLE
  export REQUESTS_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
  export SSL_CERT_FILE=$ZSCALER_COMBINED_BUNDLE

  if [[ -f $ZSCALER_JAVA_TRUSTSTORE ]]; then
    export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=$ZSCALER_JAVA_TRUSTSTORE -Djavax.net.ssl.trustStorePassword=$ZSCALER_JAVA_TRUSTSTORE_PASS -Djavax.net.ssl.trustStoreType=PKCS12"
  fi
  # cheap staleness hint, no build at shell startup
  [[ $ZSCALER_COMBINED_BUNDLE -nt $ZSCALER_JAVA_TRUSTSTORE ]] && echo "zscaler: java truststore is missing or older than the bundle (zscaler_java_truststore_build)" >&2
}

zscaler_bundle_off() {
  unset AWS_CA_BUNDLE
  unset CURL_CA_BUNDLE
  unset HEX_CACERTS_PATH
  unset NODE_EXTRA_CA_CERTS
  unset PIP_CERT
  unset REQUESTS_CA_BUNDLE
  unset SSL_CERT_FILE

  unset JAVA_TOOL_OPTIONS
}

zscaler_java_truststore_build() {
  local src=$ZSCALER_COMBINED_BUNDLE out=$ZSCALER_JAVA_TRUSTSTORE tmp
  tmp=$(mktemp -d) || return 1
  cat > "$tmp/BuildTruststore.java" <<'EOF'
import java.io.*;
import java.security.KeyStore;
import java.security.cert.*;

public class BuildTruststore {
  public static void main(String[] a) throws Exception {
    KeyStore ks = KeyStore.getInstance("PKCS12");
    ks.load(null, null);
    int i = 0;
    try (InputStream in = new BufferedInputStream(new FileInputStream(a[0]))) {
      for (Certificate c : CertificateFactory.getInstance("X.509").generateCertificates(in)) {
        ks.setCertificateEntry("ca-" + i++, c);
      }
    }
    try (OutputStream out = new FileOutputStream(a[1])) { ks.store(out, a[2].toCharArray()); }
    System.out.println("truststore: " + i + " certificates -> " + a[1]);
  }
}
EOF
  # `mise x java@...` or any java on PATH; java BuildTruststore.java runs the source file directly (JDK 11+)
  java "$tmp/BuildTruststore.java" "$src" "$out" "$ZSCALER_JAVA_TRUSTSTORE_PASS"
  local rc=$?
  rm -rf "$tmp"
  return $rc
}