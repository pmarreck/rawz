# Sony ARW2 compressed packet evidence, 2026-10-10

## Exact variant and control

The selected control is raw.pixls.us id 2414, `Sony - ILCE-7M3 - 14bit 14bit compressed (3:2).ARW`. The live repository row identified it as CC0 on 2026-10-10 and again on 2026-10-14. Its SHA-256 is `250784580ea527442c09004417bb0eead484f2bf3ee8f9121a776ac65bb50d0f`, and its size is 25,639,680 bytes.

ExifTool 13.59 reports a Sony ILCE-7M3 14-bit Bayer CFA SubIFD with Compression 32767, dimensions 6,048 by 4,024, one strip at host offset 1,302,528, and a 24,337,152-byte strip count. The payload ends at file offset 25,639,680 and its byte count equals `width * height`.

The recovered independent control used `/nix/store/xmhvnay2vvwssk770jxyip1kgzrnqmyp-darktable-5.6.0/bin/darktable-cli`, whose SHA-256 is `763c9b14ab75e4e326098b8fd8cfef5e648b614d2fc1ee302dcdee1498c4883f`. darktable 5.6.0/rawspeed accepted the pristine file and produced a 64-pixel PPM with SHA-256 `11adfad514d862428bff0887228201b08f01f646db42e990bc7643adde0b7dd8`. Removing the final file byte, which is also the final declared sensor byte, made rawspeed report truncation and return failure. This oracle pair was recovered from the launch-priority evidence rather than rerun during the provider hold.

## Packet grammar and specificity controls

The 24,337,152-byte payload contains 1,521,072 fixed 16-byte packets. Each packet stores 11-bit maximum and minimum values, two four-bit positions, and fourteen seven-bit deltas. The field layout and little-endian extraction match dcraw 9.28 `sony_arw2_load_raw`; the compression model is also described by Dietz and Eberhart, “Sony ARW2 compression: artifacts and credible repair,” DOI `10.2352/ISSN.2470-1173.2016.2.VIPC-227`.

A complete read-only scan of the pristine payload found:

| Observation | Count |
|---|---:|
| packets with maximum below minimum | 0 |
| packets with coincident extrema positions | 0 |
| packets with maximum equal to minimum | 258 |
| decoded delta samples above the packet's stored maximum | 28,086 |

The last two rows are specificity controls. Maximum equal to minimum is legal. A delta reconstruction above the stored maximum is also accepted by the decoder, which clamps only at the 11-bit domain limit; rejecting either condition would create false positives on this pristine file. The first implementation therefore rejects only maximum below minimum and coincident positions when maximum and minimum differ.

Fourteen deltas occupy 98 of each packet's 128 bits, and every seven-bit pattern is representable. Under the declared packet-only grammar, 98/128, or 76.5625%, is a lower bound on bits whose in-place changes cannot trigger these grammar failures. Some header changes also preserve the checked relations. This is a bound for the implemented check set, not a format-wide unavoidable miss-rate proof, proof that every changed image is semantically valid, or a measured mutation false-negative rate. A successful pass remains `structural(analytical_ceiling_unestablished)`.

## TDD receipts

- RED: `build-budget --project rawz -- nix develop -c zig build test`, unit `build-rawz-28fcc78e-3629-40f0-b813-68bfa0912a1b.scope`, exited 1 because append-only `sensor_validation.ErrorCode.invalid_packet_header` did not exist.
- First implementation check: unit `build-rawz-90bf32b9-401d-4614-bc53-815324cc9447.scope` exited 1 because PEF's legacy reverse error mapper exhaustively switched over the shared error domain. Adding the Sony-only code to that mapper's impossible cross-domain fallback did not change PEF behavior.
- Packet GREEN: unit `build-rawz-588e4e17-8a6c-4244-a03c-4455d28c0e5c.scope` exited 0.
- Locator RED: unit `build-rawz-f980da75-4570-44e9-95ce-3f3da315b75e.scope` exited 1 with 65 passes, one skip, and only the locator test failing because the stub returned structural reach instead of the expected payload.
- Locator GREEN: unit `build-rawz-827fcc9b-0d1a-4512-a05f-773feedb811b.scope` exited 0 after bounded CFA SubIFD discovery and exact single-strip extent checking were added.
- Complete GREEN: unit `build-rawz-d2140b9e-35d3-4ef3-a873-e24bb93059de.scope` ran `./test` and `./build` with the exact CC0 fixture enabled. Sandboxed ReleaseSafe tests, the package build, the private dependency control, the exact external-fixture checks, and the optimized build all passed.

The JPEG provider hold remains unchanged. This lane imports only the permitted `tiffz-parser` surface for TIFF facts and performs Sony packet checks in rawz; it does not add, fetch, repin, or route around a JPEG provider.
