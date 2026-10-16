import test from "node:test";
import assert from "node:assert/strict";
import { createFrameBudget } from "../src/frame-budget.js";

test("mobile Auto lowers resolution after sustained slow animation frames", () => {
  const budget = createFrameBudget({ mode: "auto", mobile: true, baseRatio: 1.25 });
  for (let i = 0; i < 5; i++) budget.observeFrame(41);
  assert.equal(budget.ratio, 1.25, "Transient lag must not lower resolution");
  budget.observeFrame(41);
  assert.equal(budget.ratio, 1.05);
  assert.equal(budget.adjustments, 1);
  for (let i = 0; i < 60; i++) budget.observeFrame(45);
  assert.ok(budget.ratio >= .8 && budget.ratio < 1);
  assert.ok(budget.adjustments > 1);
});

test("Auto can restore quality only after long sustained fast frame cadence", () => {
  const budget = createFrameBudget({ mode: "auto", mobile: true, baseRatio: 1.25 });
  for (let i = 0; i < 24; i++) budget.observeFrame(38);
  assert.equal(budget.ratio, .8);
  for (let i = 0; i < 47; i++) budget.observeFrame(16.7);
  assert.equal(budget.ratio, .8);
  budget.observeFrame(16.7);
  assert.equal(budget.ratio, .9);
  for (let i = 0; i < 500; i++) budget.observeFrame(16.7);
  assert.equal(budget.ratio, 1.25, "DPR must never exceed user's base");
});

test("manual Eco or Detailed modes never alter visual clarity automatically", () => {
  for (const mode of ["eco", "high"]) {
    const budget = createFrameBudget({
      mode, mobile: true, baseRatio: mode === "high" ? 1.75 : 1
    });
    for (let i = 0; i < 100; i++) {
      budget.observeFrame(i % 2 ? 52 : 12);
    }
    assert.equal(budget.ratio, mode === "high" ? 1.75 : 1);
    assert.equal(budget.adjustments, 0);
  }
});

test("desktop and background/interrupted frames are ignored", () => {
  const desktop = createFrameBudget({ mode: "auto", mobile: false });
  for (let i = 0; i < 100; i++) desktop.observeFrame(40);
  assert.equal(desktop.ratio, 1.25);
  const android = createFrameBudget({ mode: "auto", mobile: true });
  for (let i = 0; i < 200; i++) {
    android.observeFrame(NaN);
    android.observeFrame(Infinity);
    android.observeFrame(0);
    android.observeFrame(240);
  }
  assert.equal(android.ratio, 1.25);
  assert.equal(android.adjustments, 0);
});

test("cadence estimates are bounded even with atypical configured DPR", () => {
  const small = createFrameBudget({
    mode: "auto", mobile: true, baseRatio: .75
  });
  for (let i = 0; i < 120; i++) small.observeFrame(42);
  assert.ok(small.ratio >= .6 && small.ratio <= .75);
  assert.equal(small.observeFrame(-1), small.ratio);
});
