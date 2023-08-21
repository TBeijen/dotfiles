# Create this bundle by combining a suitable root certificate bundle with the zscaler root certificate
# 
# Using brew, probably this bundle exists:
#    openssl storeutl -noout -text -certs /usr/local/etc/ca-certificates/cert.pem
# From zscaler, probably this certificate exists:
#    openssl storeutl -noout -text -certs ~/.zcli/zscaler_root.pem
#
# Alternatively, locate in OSX Keychain, export zscaler as pem (System) and all certs into single pem (System roots)
#
# Concat pems into single bundle:
#
#   cat /usr/local/etc/ca-certificates/cert.pem > ~/.zscaler/bundle_combined.pem
#   cat ~/.zcli/zscaler_root.pem >> ~/.zscaler/bundle_combined.pem
#
ZSCALER_COMBINED_BUNDLE=~/.zscaler/bundle_combined.pem

zscaler_bundle_on() {
	export AWS_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
	export PIP_CERT=$ZSCALER_COMBINED_BUNDLE
	export REQUESTS_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
	export CURL_CA_BUNDLE=$ZSCALER_COMBINED_BUNDLE
	export NODE_EXTRA_CA_CERTS=$ZSCALER_COMBINED_BUNDLE
}

zscaler_bundle_off() {
  unset AWS_CA_BUNDLE
  unset PIP_CERT
  unset REQUESTS_CA_BUNDLE
  unset CURL_CA_BUNDLE
  unset NODE_EXTRA_CA_CERTS
}