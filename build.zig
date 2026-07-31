const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.option(
		std.builtin.OptimizeMode,
		"optimize",
		"Optimization mode (default: ReleaseFast)",
	) orelse .ReleaseFast;

	// ── Core library module (pure Zig, no I/O) ──────────────────────────
	// Exposed for downstream Zig consumers (validate). Per the fleet's
	// sibling-Zig exception, consumers MAY import this module directly
	// because the C CLI below dogfoods the FFI.
	const core_mod = b.addModule("rawz", .{
		.root_source_file = b.path("src/lib.zig"),
		.target = target,
		.optimize = optimize,
	});
	_ = core_mod;

	// ── Static library with C ABI (the FFI boundary) ────────────────────
	const lib = b.addLibrary(.{
		.name = "rawz",
		.linkage = .static,
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/lib.zig"),
			.target = target,
			.optimize = optimize,
			.link_libc = true,
		}),
	});
	b.installArtifact(lib);

	// ── C CLI (deliberately C: it CANNOT @import the Zig core) ──────────
	const cli_mod = b.createModule(.{
		.target = target,
		.optimize = optimize,
		.link_libc = true,
	});
	cli_mod.addCSourceFile(.{
		.file = b.path("cli/main.c"),
		.flags = &.{ "-std=c11", "-Wall", "-Wextra", "-Wpedantic" },
	});
	cli_mod.addIncludePath(b.path("include"));
	// Zig 0.16: linkLibrary lives on the MODULE, not on Compile.
	// `cli.linkLibrary(lib)` (the 0.12-0.15 form) fails with
	// "no field or member function named 'linkLibrary' in 'Build.Step.Compile'".
	cli_mod.linkLibrary(lib);
	const cli = b.addExecutable(.{
		.name = "rawz",
		.root_module = cli_mod,
	});
	b.installArtifact(cli);

	const run_cmd = b.addRunArtifact(cli);
	run_cmd.step.dependOn(b.getInstallStep());
	if (b.args) |args| run_cmd.addArgs(args);
	b.step("run", "Run the CLI").dependOn(&run_cmd.step);

	const run_tests = b.addRunArtifact(b.addTest(.{
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/lib.zig"),
			.target = target,
			.optimize = optimize,
		}),
	}));
	b.step("test", "Run unit tests").dependOn(&run_tests.step);
}
