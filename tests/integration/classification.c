#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "rawz.h"

#define CHECK(condition) do { \
	if (!(condition)) { \
		fprintf(stderr, "classification FFI check failed at line %d\n", __LINE__); \
		return 1; \
	} \
} while (0)

_Static_assert(RAWZ_STATUS_OK == 0, "success status must remain zero");
_Static_assert(RAWZ_FORMAT_DNG == 2, "published DNG value changed");
_Static_assert(RAWZ_FORMAT_RAW_UNKNOWN == 10, "published format values changed");

int main(void) {
	static const uint8_t dng[] = {
		'I', 'I', 0x2a, 0x00, 0x08, 0x00, 0x00, 0x00,
		0x01, 0x00,
		0x12, 0xc6, 0x01, 0x00, 0x04, 0x00, 0x00, 0x00,
		0x01, 0x04, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00
	};
	rawz_format_t format = RAWZ_FORMAT_UNKNOWN;

	CHECK(rawz_version() != NULL);
	CHECK(rawz_classify_buffer(dng, sizeof(dng), &format) == RAWZ_STATUS_OK);
	CHECK(format == RAWZ_FORMAT_DNG);
	CHECK(rawz_classify_buffer(NULL, 0, &format) == RAWZ_STATUS_INVALID_ARGUMENT);
	CHECK(rawz_classify_buffer(dng, sizeof(dng), NULL) == RAWZ_STATUS_INVALID_ARGUMENT);

	return 0;
}
