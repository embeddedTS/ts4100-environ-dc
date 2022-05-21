################################################################################
#
# ts4100-environ
#
################################################################################

TS4100_ENVIRON_AUTORECONF = YES
TS4100_ENVIRON_VERSION = v2.0
TS4100_ENVIRON_SITE = $(call github,embeddedTS,ts4100-environ-dc,$(TS4100_ENVIRON_VERSION))

TS4100_ENVIRON_DEPENDENCIES = host-pkgconf pango cairo fontconfig

$(eval $(autotools-package))
