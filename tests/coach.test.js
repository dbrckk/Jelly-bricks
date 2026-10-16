import test from "node:test";
import assert from "node:assert/strict";
import { COACH_KEY, GUIDE_COPY, guideStep } from "../src/coach.js";

test("guide has a versioned local storage key and helpful French copy", () => {
  assert.equal(COACH_KEY, "jelly-bricks-guide-v1");
  for (const key of ["choose", "place", "hint", "continue", "learned"]) {
    assert.ok(GUIDE_COPY[key].title.length > 6);
    assert.ok(GUIDE_COPY[key].message.length > 15);
  }
});

test("first-play guide progresses with actual puzzle state", () => {
  assert.equal(guideStep({}), "choose");
  assert.equal(guideStep({ selected: "A" }), "place");
  assert.equal(guideStep({ selected: "A", showHint: true }), "hint");
  assert.equal(guideStep({ placedPieces: 1 }), "continue");
  assert.equal(guideStep({ placedPieces: 1, selected: "B" }), "continue");
  assert.equal(guideStep({ placedPieces: 2 }), "learned");
  assert.equal(guideStep({ placedPieces: 11, won: true }), "learned");
});

test("guide never gates gameplay when an already solved puzzle is loaded", () => {
  assert.equal(guideStep({ placedPieces: 0, won: true }), "learned");
  assert.equal(guideStep({ placedPieces: 2, showHint: true }), "learned");
});
