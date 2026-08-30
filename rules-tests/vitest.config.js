import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // The emulator is a shared resource: parallel suites would race on the
    // same documents and produce failures that have nothing to do with rules.
    fileParallelism: false,
    testTimeout: 20_000,
    hookTimeout: 20_000,
  },
});
