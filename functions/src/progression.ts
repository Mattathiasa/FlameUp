/**
 * The progression rules, mirrored from the Dart implementation in
 * `lib/features/gamification/domain/`.
 *
 * They are duplicated deliberately. The client computes an expected award so
 * it can show a plausible figure immediately; the server computes the real one
 * and its answer is what gets written. Sharing the code would mean shipping
 * the server's rules to the client, where they could be read and gamed.
 *
 * The Dart tests and these must agree. `test/features/gamification/` is the
 * specification for both.
 */

/** Cumulative XP required to reach each level. Index 0 is level 1. */
export function standardThresholds(): number[] {
  return Array.from({ length: 60 }, (_, index) => {
    const level = index + 1;
    if (level === 1) return 0;
    const n = level - 1;
    return 120 * n + 15 * n * n;
  });
}

export function levelFor(xp: number, thresholds = standardThresholds()): number {
  if (xp <= 0) return 1;
  for (let index = thresholds.length - 1; index >= 0; index--) {
    if (xp >= thresholds[index]!) return index + 1;
  }
  return 1;
}

/** `YYYY-MM-DD` for an instant in a given IANA timezone. */
export function dayKey(date: Date, timeZone: string): string {
  // A streak is a question about calendar days where the user is, so the date
  // is resolved in their zone rather than in UTC.
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(date);
  } catch {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: 'UTC',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(date);
  }
}

export function daysBetween(from: string, to: string): number | null {
  const start = Date.parse(from);
  const end = Date.parse(to);
  if (Number.isNaN(start) || Number.isNaN(end)) return null;
  return Math.round((end - start) / 86_400_000);
}

export interface StreakState {
  current: number;
  longest: number;
  lastCookedOn: string | null;
  freezeDaysLeft: number;
}

/**
 * The streak after finishing a dish on `today`.
 *
 * Same day leaves it unchanged, the next day extends it, exactly one missed
 * day is forgiven if a freeze remains, and anything longer resets to 1.
 */
export function streakAfterCook(state: StreakState, today: string): StreakState {
  const fresh = {
    current: 1,
    longest: Math.max(state.longest, 1),
    lastCookedOn: today,
    freezeDaysLeft: state.freezeDaysLeft,
  };

  if (!state.lastCookedOn) return fresh;

  const gap = daysBetween(state.lastCookedOn, today);
  // Unreadable date, or a clock that went backwards.
  if (gap === null || gap < 0) return fresh;
  if (gap === 0) return state;

  if (gap === 1) {
    const current = state.current + 1;
    return {
      current,
      longest: Math.max(state.longest, current),
      lastCookedOn: today,
      freezeDaysLeft: state.freezeDaysLeft,
    };
  }

  if (gap === 2 && state.freezeDaysLeft > 0) {
    const current = state.current + 1;
    return {
      current,
      longest: Math.max(state.longest, current),
      lastCookedOn: today,
      freezeDaysLeft: state.freezeDaysLeft - 1,
    };
  }

  return fresh;
}

/** Completed cooks required for each mastery level. */
export const MASTERY_THRESHOLDS = [0, 1, 2, 3, 5, 8, 12] as const;

export function masteryLevelFor(cookCount: number): number {
  let level = 0;
  MASTERY_THRESHOLDS.forEach((required, index) => {
    if (cookCount >= required) level = index;
  });
  return level;
}

export interface XpAward {
  amount: number;
  reason: string;
  detail?: string;
}

const STREAK_MILESTONES = new Set([7, 14, 30, 60, 100]);

/** Repeat cooks decay towards a floor, so grinding one dish is not optimal. */
function decayFor(previousCooks: number): number {
  if (previousCooks < 3) return 1;
  return Math.max(0.25, 1 - (previousCooks - 2) * 0.1);
}

export function awardsForCook(options: {
  recipeXp: number;
  recipeId: string;
  previousCooks: number;
  streakAfter: number;
}): XpAward[] {
  const awards: XpAward[] = [
    {
      amount: Math.round(options.recipeXp * decayFor(options.previousCooks)),
      reason: 'recipeCompleted',
      detail: options.recipeId,
    },
  ];

  if (options.previousCooks === 0) {
    awards.push({
      amount: 50,
      reason: 'firstTimeCooking',
      detail: options.recipeId,
    });
  }

  if (STREAK_MILESTONES.has(options.streakAfter)) {
    awards.push({
      amount: 100,
      reason: 'streakMilestone',
      detail: String(options.streakAfter),
    });
  }

  return awards;
}

export function totalOf(awards: XpAward[]): number {
  return awards.reduce((sum, award) => sum + award.amount, 0);
}
