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

typedef enum rawz_verdict_t {
	RAWZ_VERDICT_ACCEPTED = 0,
	RAWZ_VERDICT_REJECTED = 1
} rawz_verdict_t;

typedef enum rawz_reach_t {
	RAWZ_REACH_NONE = 0,
	RAWZ_REACH_FULL = 1,
	RAWZ_REACH_STRUCTURAL = 2
} rawz_reach_t;

typedef enum rawz_reach_reason_t {
	RAWZ_REACH_REQUIRES_TIFF_DECOMPRESSION = 0,
	RAWZ_REACH_ENCODED_PAYLOAD_REQUIRED = 1,
	RAWZ_REACH_SAMPLE_VALUES_HAVE_NO_INTEGRITY_SIGNAL = 2,
	RAWZ_REACH_HUFFMAN_TABLE_UNAVAILABLE = 3,
	RAWZ_REACH_UNSUPPORTED_COMPRESSION = 4,
	RAWZ_REACH_UNSUPPORTED_METADATA_LAYOUT = 5,
	RAWZ_REACH_METADATA_LEVELS_UNAVAILABLE = 6,
	RAWZ_REACH_WORK_LIMIT_EXCEEDED = 7,
	RAWZ_REACH_ANALYTICAL_CEILING_UNESTABLISHED = 8,
	RAWZ_REACH_REASON_NONE = 65535
} rawz_reach_reason_t;

typedef enum rawz_rejection_t {
	RAWZ_REJECTION_NONE = 0,
	RAWZ_REJECTION_MALFORMED_TIFF = 1,
	RAWZ_REJECTION_INVALID_SEMANTIC_TAG = 2,
	RAWZ_REJECTION_LIMIT_EXCEEDED = 3, /* Legacy value; work limits use call status. */
	RAWZ_REJECTION_UNSUPPORTED_TIFF_FEATURE = 4,
	RAWZ_REJECTION_NOT_CAMERA_RAW = 5,
	RAWZ_REJECTION_SENSOR = 6
} rawz_rejection_t;

typedef enum rawz_sensor_error_t {
	RAWZ_SENSOR_INVALID_DIMENSIONS = 0,
	RAWZ_SENSOR_UNSUPPORTED_BIT_DEPTH = 1,
	RAWZ_SENSOR_INVALID_HUFFMAN_TABLE = 2,
	RAWZ_SENSOR_INVALID_HUFFMAN_CODE = 3,
	RAWZ_SENSOR_TRUNCATED = 4,
	RAWZ_SENSOR_SAMPLE_OVERFLOW = 5,
	RAWZ_SENSOR_WORK_LIMIT_EXCEEDED = 6,
	RAWZ_SENSOR_TRAILING_MISMATCH = 7,
	RAWZ_SENSOR_METADATA_OUT_OF_BOUNDS = 8,
	RAWZ_SENSOR_MALFORMED_METADATA = 9,
	RAWZ_SENSOR_SAMPLE_BELOW_BLACK_LEVEL = 10,
	RAWZ_SENSOR_SAMPLE_ABOVE_WHITE_LEVEL = 11,
	RAWZ_SENSOR_INVALID_PACKET_HEADER = 12,
	RAWZ_SENSOR_ERROR_NONE = 65535
} rawz_sensor_error_t;

typedef enum rawz_region_t {
	RAWZ_REGION_NONE = 0,
	RAWZ_REGION_PAYLOAD = 1,
	RAWZ_REGION_METADATA = 2
} rawz_region_t;

typedef struct rawz_validation_t {
	rawz_verdict_t verdict;
	rawz_format_t format;
	rawz_reach_t reach;
	rawz_reach_reason_t reach_reason;
	rawz_rejection_t rejection;
	rawz_sensor_error_t sensor_error;
	rawz_region_t region;
	uint64_t byte_offset;
} rawz_validation_t;

/* Returns borrowed process-lifetime storage. Never modify or free it. */
const char* rawz_version(void);

/* Borrows data for this call. Writes out_format only on RAWZ_STATUS_OK. */
rawz_status_t rawz_classify_buffer(
	const uint8_t* data,
	size_t len,
	rawz_format_t* out_format
);

/* Runs all full-file checks reachable for this RAW variant. A malformed input
 * is a successful call with verdict REJECTED; status reports API/tool errors.
 * LIMIT_EXCEEDED is an incomplete check, not a file verdict. Writes
 * out_validation only on OK. */
rawz_status_t rawz_validate_buffer(
	const uint8_t* data,
	size_t len,
	rawz_validation_t* out_validation
);

#endif /* RAWZ_H */
