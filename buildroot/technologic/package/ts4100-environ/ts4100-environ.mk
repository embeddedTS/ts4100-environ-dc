################################################################################
#
# ts4100-environ
#
################################################################################

TS4100_ENVIRON_AUTORECONF = YES
TS4100_ENVIRON_VERSION = v1.2
TS4100_ENVIRON_SITE = $(call github,embeddedarm,ts4100-environ-dc,$(TS4100_ENVIRON_VERSION))

TS4100_ENVIRON_DEPENDENCIES = host-pkgconf pango cairo fontconfig

$(eval $(autotools-package))
