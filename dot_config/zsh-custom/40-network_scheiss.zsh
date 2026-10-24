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

# Source this file,then call below function in bashrc/zshrc and the likes
zscaler_bundle_on() {
  export AWS_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
  export CURL_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
  export HEX_CACERTS_PATH=$ZSCALER_COMBINED_BUNDLE
  export NODE_EXTRA_CA_CERTS=$ZSCALER_COMBINED_BUNDLE
  export PIP_CERT=$ZSCALER_COMBINED_BUNDLE
  export REQUESTS_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
  export SSL_CERT_FILE=$ZSCALER_COMBINED_BUNDLE
}

zscaler_bundle_off() {
  unset AWS_CA_BUNDLE
  unset CURL_CA_BUNDLE
  unset HEX_CACERTS_PATH
  unset NODE_EXTRA_CA_CERTS
  unset PIP_CERT
  unset REQUESTS_CA_BUNDLE
  unset SSL_CERT_FILE
}
