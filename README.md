# swift-legibility

Whether drawn text can be read, measured on the pixels rather than judged by
eye. CoreGraphics and Vision only: no UI frameworks, no video, no network.
macOS 14+ / iOS 17+.

| Piece | What it measures |
|---|---|
| `InkBox` | Where something actually drew: the bounds of pixels above 8% alpha, so an outline, shadow or plate that reaches past a layout box is counted. `overflow(_:inside:)` gives how far it reaches past a rectangle on each side. |
| `LetterRing` | WCAG contrast between the median luminance of the letters' interior and a thin ring of pixels touching them (3 reference points out, at least 2 px). A stroke or plate in that ring counts; a bright patch of photograph pressing against thin letters counts against them. |
| `Contrast` | WCAG 2 relative luminance and ratio, the 3:1 / 4.5:1 thresholds, and the least plate opacity that reaches a target. |
| `ReadBack` | The share of the expected words that on-device text recognition (`.accurate`, no language correction) reads back from the finished picture. `measure` returns `nil` when recognition could not run at all (a busy Neural Engine fails requests outright; they are retried, then run on the CPU), so a failure is never reported as unreadable text. |
| `Pixels`, `Morphology` | RGBA bytes, alpha masks, luminance maps, and mask grow/shrink. |
| `VisionRetry` | Any Vision request run so a busy Neural Engine is not mistaken for an answer: asked again, then on the CPU (`attempts`, `perform`, `runOnCPU`). A request that may use the Neural Engine is waited for at most 20 s (`neuralEngineTimeout`): a wedged Neural Engine compiler once left every request blocked at 0 % CPU, so past the limit the request is abandoned and every later one in the process runs on the CPU (`cpuOnly`; `LEGIBILITY_VISION_CPU=1` starts there). `ReadBack` runs through it; so can a caller's own requests (subject masks, faces). |
| `VisionQueue` | `run { … }` — blocking Vision work moved off Swift concurrency's cooperative pool onto a dispatch queue. Several Vision requests waiting at once on the pool was measured to deadlock every thread in it. |

```swift
import Legibility

let ink = InkBox.bounds(of: textLayer)                       // pixels, top-left
let contrast = LetterRing.measure(composite: finished,
                                  letters: Pixels.mask(of: lettersOnly),
                                  referenceScale: Double(finished.height) / 1000)
let read = ReadBack.readFraction(of: "Night Drive", in: finished)
```

The measurements were first written for caption checks (swift-caption-kit)
and moved here so every tool that puts words on pictures measures them the
same way. The first OCR call in a process loads Vision's recogniser, which can
take seconds; later calls are fast.

## License

MIT — see [LICENSE](LICENSE).
