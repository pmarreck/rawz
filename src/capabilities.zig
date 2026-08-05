//! Machine-checked declaration of rawz's bounded v1 professional RAW support.

const std = @import("std");
const pef_decoder = @import("pef_decoder.zig");

pub const json = @embedFile("CAPABILITIES.json");

test "capability matrix is complete, honest, and internally consistent" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    try std.testing.expectEqual(@as(i64, 1), root.get("schema_version").?.integer);
    const families = root.get("families").?.array.items;
    try std.testing.expect(families.len >= 15);

    var partial_count: usize = 0;
    var unsupported_count: usize = 0;
    for (families) |family_value| {
        const family = family_value.object;
        try std.testing.expect(family.get("id").?.string.len > 0);
        try std.testing.expect(family.get("evidence").?.string.len > 0);
        const state = family.get("validation_state").?.string;
        if (std.mem.eql(u8, state, "strict")) {
            // The state is part of the schema even though no complete RAW
            // family currently earns it.
        } else if (std.mem.eql(u8, state, "partial")) {
            partial_count += 1;
        } else if (std.mem.eql(u8, state, "unsupported")) {
            unsupported_count += 1;
        } else {
            return error.InvalidCapabilityState;
        }
    }

    try std.testing.expect(partial_count > 0);
    try std.testing.expect(unsupported_count > 0);

    const production = root.get("production_dependencies").?.array.items;
    try std.testing.expectEqual(@as(usize, 1), production.len);
    try std.testing.expectEqualStrings("tiffz", production[0].string);

    const oracles = root.get("dev_test_oracles_only").?.array.items;
    try std.testing.expect(oracles.len > 0);
    for (oracles) |oracle| {
        for (production) |dependency| {
            try std.testing.expect(!std.mem.eql(u8, oracle.string, dependency.string));
        }
    }

    const closure = root.get("production_closure").?.object;
    try std.testing.expectEqualStrings("clean", closure.get("status").?.string);
    try std.testing.expectEqualStrings("tiffz-parser", closure.get("module").?.string);
    try std.testing.expectEqualStrings(
        "c57166db87132742c7591c34161c5549133bd09a",
        closure.get("tiffz_commit").?.string,
    );

    const declared = root.get("bounded_scorecards").?.object.get("pef_huffman_sparse_code").?.object;
    const measured = pef_decoder.measureV1Gate();
    try std.testing.expectEqual(@as(i64, @intCast(measured.valid_total)), declared.get("known_good").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.false_positives)), declared.get("false_positives").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.known_bad_total)), declared.get("known_bad").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.false_negatives)), declared.get("false_negatives").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.sniper_detected)), declared.get("sniper_detected").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.sniper_total)), declared.get("sniper_total").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.bolter_detected)), declared.get("bolter_detected").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.bolter_total)), declared.get("bolter_total").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.shotgun_detected)), declared.get("shotgun_detected").?.integer);
    try std.testing.expectEqual(@as(i64, @intCast(measured.shotgun_total)), declared.get("shotgun_total").?.integer);
}
