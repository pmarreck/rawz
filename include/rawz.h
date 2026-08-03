#ifndef RAWZ_H
#define RAWZ_H

#include <stddef.h>
#include <stdint.h>

/* rawz — cleanroom camera RAW parsing and validation.
 * This header is the real public API; the CLI dogfoods it. */

typedef enum rawz_status_t {
	RAWZ_STATUS_OK = 0,
	RAWZ_STATUS_INVALID_ARGUMENT = 1,
	RAWZ_STATUS_MALFORMED_TIFF = 2,
	RAWZ_STATUS_INVALID_SEMANTIC_TAG = 3,
	RAWZ_STATUS_LIMIT_EXCEEDED = 4,
	RAWZ_STATUS_OUT_OF_MEMORY = 5,
	RAWZ_STATUS_IO = 6,
	RAWZ_STATUS_UNSUPPORTED_TIFF_FEATURE = 7,
	RAWZ_STATUS_INTERNAL = 8
} rawz_status_t;

typedef enum rawz_format_t {
	RAWZ_FORMAT_UNKNOWN = 0,
	RAWZ_FORMAT_TIFF = 1,
	RAWZ_FORMAT_DNG = 2,
	RAWZ_FORMAT_CR2 = 3,
	RAWZ_FORMAT_NEF = 4,
	RAWZ_FORMAT_ARW = 5,
	RAWZ_FORMAT_ORF = 6,
	RAWZ_FORMAT_PEF = 7,
	RAWZ_FORMAT_3FR = 8,
	RAWZ_FORMAT_RW2 = 9,
	RAWZ_FORMAT_RAW_UNKNOWN = 10
} rawz_format_t;

/* Returns borrowed process-lifetime storage. Never modify or free it. */
const char* rawz_version(void);

/* Borrows data for this call. Writes out_format only on RAWZ_STATUS_OK. */
rawz_status_t rawz_classify_buffer(
	const uint8_t* data,
	size_t len,
	rawz_format_t* out_format
);

#endif /* RAWZ_H */
