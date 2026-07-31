#include <stdio.h>
#include "rawz.h"

/* Deliberately C: it CANNOT @import the Zig core, so the FFI boundary
 * that every external consumer uses is exercised by construction. */
int main(int argc, char* argv[]) {
	(void)argc;
	(void)argv;
	printf("rawz version %s\n", rawz_version());
	return 0;
}
