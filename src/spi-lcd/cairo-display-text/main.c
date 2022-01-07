/* SPDX-License-Identifier: BSD-2-Clause */

#include <cairo/cairo.h>
#include <fontconfig/fontconfig.h>
#include <math.h>
#include <pango/pangocairo.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#include "lcd-display.h"

const char copyright[] = "Copyright (c) embeddedTS - " __DATE__ " - "
GITCOMMIT;


int main(void) {

	cairo_t *cr;
	cairo_surface_t *sfc;
	PangoLayout *layout;
	PangoFontDescription *font_desc;

	// max 25x10 printable, newline/\0 at end of lines, 27x10, 270 byte total
	char *textbuf;
	int i;
	int ret;

	lcdInfo_t *lcd;

	if ((lcd = openDisplay()) == NULL) {
		fprintf(stderr, "ERROR: Can't open display\n");
		return 1;
	}

	sfc = cairo_image_surface_create_for_data(
	  (unsigned char *)lcd->frameBuffer, CAIRO_FORMAT_A1, lcd->displayWidth,
	  lcd->displayHeight, lcd->stride);

	textbuf = (char *)calloc(270, sizeof(char));

	/* XXX: This might return NULL */
	i = 0;
	do {
		ret = fgetc(stdin);
		if (ret == EOF) break;
		textbuf[i] = ret;
		i++;
	} while (i <= 270);

	if (sfc) {
		if ((cr = cairo_create(sfc))) {
			cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE);

			/* Draw a box on the exterior-most pixels to make a good
			 * frame */
			cairo_set_line_width(cr, 1.0);
			cairo_rectangle(cr, 1, 1, lcd->displayWidth-1,
			  lcd->displayHeight-1);
			cairo_stroke(cr);

			/* Draw some text on screen
			 * This will just blindly draw all text from stdin. The
			 * text to render should be prepped and cleaned up ahead
			 * of time.
			 * Move the rendering start to the top-left point inside
			 * the drawn frame. We're going to render a pango layout
			 * starting from this point.
			 * With the font loaded, render stdin to this pango layout
			 * and draw it to the cairo surface.
			 * Can render multi-line correctly so long as \n is used
			 * as the delimiter. Will render until \0 char.
			 */
			cairo_move_to(cr, 2, 2);
			layout = pango_cairo_create_layout(cr);
			/* Line spacing may need to change for other fonts */
			pango_layout_set_line_spacing(layout, 1);
			pango_layout_set_text(layout, textbuf, -1);

			/* Load in font from description, then remove desc */
			font_desc = pango_font_description_from_string("ts pixel 4x5 5px");
			pango_layout_set_font_description(layout, font_desc);
			pango_font_description_free(font_desc);

			/* Update the pango layout with text in the right font,
			 * then render to cairo surface */
			pango_cairo_update_layout(cr, layout);
			pango_cairo_show_layout(cr, layout);
			cairo_surface_flush(sfc);

			cairo_destroy(cr);
		}
	}

	closeDisplay();

	return 0;
}


