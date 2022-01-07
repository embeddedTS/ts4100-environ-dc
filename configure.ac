#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT(ts4100-environ-dc, 1.0, support@embeddedTS.com)
AC_CONFIG_SRCDIR([src/spi-lcd/lcd-helper/spi-lcd.c])

AM_INIT_AUTOMAKE([1.00 foreign no-define])

# Checks for programs.
AC_PROG_CC
PKG_PROG_PKG_CONFIG([0.20])

# Path to the pkgconfig folder
AC_ARG_WITH([pkgconfigdir], AS_HELP_STRING([--with-pkgconfigdir=DIR],
	[Path to the pkgconfig directory @<:@LIBDIR/pkgconfig@:>@]),
	[pkgconfigdir="$withval"], [pkgconfigdir='${libdir}/pkgconfig'])
AC_SUBST([pkgconfigdir])

# Check for Pango
PKG_CHECK_MODULES(PANGO, [pangocairo >= 1.28.1])
PKG_CHECK_MODULES(PANGO, [pango >= 1.28.1])

# Check for Cairo
PKG_CHECK_MODULES(CAIRO, [cairo >= 1.16.0])

# Check for Fontconfig
PKG_CHECK_MODULES(FONTCONFIG, [fontconfig >= 2.13.1])

# Checks for header files.
AC_CHECK_HEADERS([fcntl.h stdint.h stdlib.h string.h sys/ioctl.h unistd.h])


# Checks for typedefs, structures, and compiler characteristics.
AC_C_INLINE
AC_TYPE_UINT16_T
AC_TYPE_UINT8_T

# Checks for library functions.
AC_FUNC_MALLOC
AC_FUNC_MMAP
AC_CHECK_FUNCS([bzero getpagesize memset munmap select strstr strtoul strtoull])

AC_CONFIG_FILES([
	Makefile 
	src/spi-lcd/cairo-display-text/Makefile
	src/spi-lcd/lcd-helper/Makefile 
	src/zpu/Makefile 
	scripts/Makefile
])
AC_OUTPUT
