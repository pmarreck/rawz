#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "rawz.h"

static const char* format_name(rawz_format_t format) {
	switch (format) {
	case RAWZ_FORMAT_TIFF: return "tiff";
	case RAWZ_FORMAT_DNG: return "dng";
	case RAWZ_FORMAT_CR2: return "cr2";
	case RAWZ_FORMAT_NEF: return "nef";
	case RAWZ_FORMAT_ARW: return "arw";
	case RAWZ_FORMAT_ORF: return "orf";
	case RAWZ_FORMAT_PEF: return "pef";
	case RAWZ_FORMAT_3FR: return "3fr";
	case RAWZ_FORMAT_RW2: return "rw2";
	case RAWZ_FORMAT_RAW_UNKNOWN: return "raw_unknown";
	case RAWZ_FORMAT_UNKNOWN: return "unknown";
	}
	return "unknown";
}

static const char* reach_reason_name(rawz_reach_reason_t reason) {
	switch (reason) {
	case RAWZ_REACH_REQUIRES_TIFF_DECOMPRESSION: return "requires_tiff_decompression";
	case RAWZ_REACH_ENCODED_PAYLOAD_REQUIRED: return "encoded_payload_required";
	case RAWZ_REACH_SAMPLE_VALUES_HAVE_NO_INTEGRITY_SIGNAL: return "sample_values_have_no_integrity_signal";
	case RAWZ_REACH_HUFFMAN_TABLE_UNAVAILABLE: return "huffman_table_unavailable";
	case RAWZ_REACH_UNSUPPORTED_COMPRESSION: return "unsupported_compression";
	case RAWZ_REACH_UNSUPPORTED_METADATA_LAYOUT: return "unsupported_metadata_layout";
	case RAWZ_REACH_METADATA_LEVELS_UNAVAILABLE: return "metadata_levels_unavailable";
	case RAWZ_REACH_WORK_LIMIT_EXCEEDED: return "work_limit_exceeded";
	case RAWZ_REACH_ANALYTICAL_CEILING_UNESTABLISHED: return "analytical_ceiling_unestablished";
	case RAWZ_REACH_REASON_NONE: return "none";
	}
	return "unknown";
}

static const char* rejection_name(rawz_rejection_t rejection) {
	switch (rejection) {
	case RAWZ_REJECTION_MALFORMED_TIFF: return "malformed_tiff";
	case RAWZ_REJECTION_INVALID_SEMANTIC_TAG: return "invalid_semantic_tag";
	case RAWZ_REJECTION_LIMIT_EXCEEDED: return "limit_exceeded";
	case RAWZ_REJECTION_UNSUPPORTED_TIFF_FEATURE: return "unsupported_tiff_feature";
	case RAWZ_REJECTION_NOT_CAMERA_RAW: return "not_camera_raw";
	case RAWZ_REJECTION_SENSOR: return "sensor";
	case RAWZ_REJECTION_NONE: return "none";
	}
	return "unknown";
}

static const char* sensor_error_name(rawz_sensor_error_t error) {
	switch (error) {
	case RAWZ_SENSOR_INVALID_DIMENSIONS: return "invalid_dimensions";
	case RAWZ_SENSOR_UNSUPPORTED_BIT_DEPTH: return "unsupported_bit_depth";
	case RAWZ_SENSOR_INVALID_HUFFMAN_TABLE: return "invalid_huffman_table";
	case RAWZ_SENSOR_INVALID_HUFFMAN_CODE: return "invalid_huffman_code";
	case RAWZ_SENSOR_TRUNCATED: return "truncated";
	case RAWZ_SENSOR_SAMPLE_OVERFLOW: return "sample_overflow";
	case RAWZ_SENSOR_WORK_LIMIT_EXCEEDED: return "work_limit_exceeded";
	case RAWZ_SENSOR_TRAILING_MISMATCH: return "trailing_mismatch";
	case RAWZ_SENSOR_METADATA_OUT_OF_BOUNDS: return "metadata_out_of_bounds";
	case RAWZ_SENSOR_MALFORMED_METADATA: return "malformed_metadata";
	case RAWZ_SENSOR_SAMPLE_BELOW_BLACK_LEVEL: return "sample_below_black_level";
	case RAWZ_SENSOR_SAMPLE_ABOVE_WHITE_LEVEL: return "sample_above_white_level";
	case RAWZ_SENSOR_INVALID_PACKET_HEADER: return "invalid_packet_header";
	case RAWZ_SENSOR_ERROR_NONE: return "none";
	}
	return "unknown";
}

static const char* region_name(rawz_region_t region) {
	switch (region) {
	case RAWZ_REGION_PAYLOAD: return "payload";
	case RAWZ_REGION_METADATA: return "metadata";
	case RAWZ_REGION_NONE: return "none";
	}
	return "unknown";
}

static int read_all(FILE* input, uint8_t** out_data, size_t* out_len) {
	size_t capacity = 64 * 1024;
	size_t length = 0;
	uint8_t* data = malloc(capacity);
	if (data == NULL) return -1;

	for (;;) {
		if (length == capacity) {
			if (capacity > SIZE_MAX / 2) {
				free(data);
				return -1;
			}
			capacity *= 2;
			uint8_t* grown = realloc(data, capacity);
			if (grown == NULL) {
				free(data);
				return -1;
			}
			data = grown;
		}
		size_t got = fread(data + length, 1, capacity - length, input);
		length += got;
		if (got == 0) {
			if (ferror(input)) {
				free(data);
				return -2;
			}
			break;
		}
	}
	*out_data = data;
	*out_len = length;
	return 0;
}

static void print_result(const rawz_validation_t* result) {
	if (result->verdict == RAWZ_VERDICT_ACCEPTED) {
		if (result->reach == RAWZ_REACH_FULL) {
			printf("{\"probe\":1,\"verdict\":\"accepted\",\"format\":\"%s\",\"reach\":\"full\",\"reason\":null}\n",
				format_name(result->format));
		} else {
			printf("{\"probe\":1,\"verdict\":\"accepted\",\"format\":\"%s\",\"reach\":\"structural\",\"reason\":\"%s\"}\n",
				format_name(result->format), reach_reason_name(result->reach_reason));
		}
		return;
	}

	if (result->rejection == RAWZ_REJECTION_SENSOR) {
		printf("{\"probe\":1,\"verdict\":\"rejected\",\"code\":\"%s\",\"region\":\"%s\",\"byte_offset\":%llu}\n",
			sensor_error_name(result->sensor_error), region_name(result->region),
			(unsigned long long)result->byte_offset);
	} else {
		printf("{\"probe\":1,\"verdict\":\"rejected\",\"code\":\"%s\",\"format\":\"%s\"}\n",
			rejection_name(result->rejection), format_name(result->format));
	}
}

int main(int argc, char** argv) {
	if (argc != 2) {
		fprintf(stderr, "Usage: rawz-coverage-probe FILE|-\n");
		return 2;
	}

	FILE* input = stdin;
	if (strcmp(argv[1], "-") != 0 && strcmp(argv[1], "@stdin") != 0) {
		input = fopen(argv[1], "rb");
		if (input == NULL) {
			fprintf(stderr, "rawz-coverage-probe: cannot open %s: %s\n", argv[1], strerror(errno));
			return 2;
		}
	}

	uint8_t* data = NULL;
	size_t length = 0;
	int read_status = read_all(input, &data, &length);
	if (input != stdin) fclose(input);
	if (read_status != 0) {
		fprintf(stderr, "rawz-coverage-probe: could not read input\n");
		return 2;
	}

	rawz_validation_t result;
	rawz_status_t status = rawz_validate_buffer(data, length, &result);
	free(data);
	if (status != RAWZ_STATUS_OK) {
		fprintf(stderr, "rawz-coverage-probe: rawz API failure %d\n", (int)status);
		return 2;
	}
	print_result(&result);
	return result.verdict == RAWZ_VERDICT_ACCEPTED ? 0 : 1;
}
