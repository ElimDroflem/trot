// Vercel Edge Function — dog-voice
//
// LLM proxy: takes a dog profile + a "kind" + light context, returns a short
// dog-voice line (or paragraph for recap). Surfaces in iOS:
//   - kind="daily"           → Home daily line, refreshed every 24h
//   - kind="walk_complete"   → post-walk celebration overlay, fresh per walk
//   - kind="insight"         → "Luna says…" row in Insights, refreshed weekly
//   - kind="recap"           → narrative paragraph in the weekly recap
//   - kind="decay"           → quiet nudge after 3+ days with no walks
//   - kind="onboarding_card" → first-card moment after photo upload
//
// On any failure (timeout, upstream error, malformed output), the iOS app
// falls back to its templated DogVoiceService output silently.
//
// All copy follows brand.md voice rules: dog-as-speaker, British English,
// no shame, no fake urgency, no dog-body puns, no em dashes. Celebration
// kinds (walk_complete, onboarding_card) get permission to use exclamation
// marks; routine kinds stay calm.

export const config = { runtime: "edge" };

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-haiku-4-5-20251001";
const TIMEOUT_MS = 8_000;

type Kind =
    | "daily"
    | "walk_complete"
    | "insight"
    | "recap"
    | "decay"
    | "onboarding_card"
    | "moment_unlock";

interface DogInfo {
    name: string;
    breed: string;
    ageMonths: number;
    lifeStage: "puppy" | "adult" | "senior";
}

interface RequestBody {
    installToken: string;
    kind: Kind;
    dog: DogInfo;
    context?: Record<string, unknown>;
}

interface SuccessResponse {
    text: string;
    modelVersion: string;
    source: "llm";
}

interface ErrorResponse {
    error: string;
}

export default async function handler(req: Request): Promise<Response> {
    if (req.method !== "POST") {
        return json({ error: "method_not_allowed" }, 405);
    }

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
        return json({ error: "server_misconfigured" }, 500);
    }

    let body: RequestBody;
    try {
        body = (await req.json()) as RequestBody;
    } catch {
        return json({ error: "invalid_json" }, 400);
    }

    const validation = validate(body);
    if (validation) {
        return json({ error: validation }, 400);
    }

    const prompt = buildPrompt(body.kind, body.dog, body.context ?? {});

    let raw: string;
    try {
        raw = await callAnthropic(apiKey, prompt);
    } catch (err) {
        const reason = err instanceof Error && err.name === "AbortError" ? "timeout" : "upstream_error";
        console.error("anthropic_call_failed", { reason, kind: body.kind });
        return json({ error: reason }, 502);
    }

    const cleaned = sanitize(raw, body.kind);
    if (!cleaned) {
        console.error("llm_output_empty", { kind: body.kind, sample: raw.slice(0, 120) });
        return json({ error: "llm_output_invalid" }, 502);
    }

    return json({ text: cleaned, modelVersion: MODEL, source: "llm" }, 200);
}

// MARK: - Validation

const ALLOWED_KINDS: Kind[] = ["daily", "walk_complete", "insight", "recap", "decay", "onboarding_card", "moment_unlock"];

function validate(body: RequestBody): string | null {
    if (!body || typeof body !== "object") return "invalid_body";
    if (typeof body.installToken !== "string" || body.installToken.length < 8) return "invalid_install_token";
    if (!ALLOWED_KINDS.includes(body.kind)) return "invalid_kind";
    const d = body.dog;
    if (!d || typeof d !== "object") return "invalid_dog";
    if (typeof d.name !== "string" || d.name.length === 0 || d.name.length > 40) return "invalid_name";
    if (typeof d.breed !== "string") return "invalid_breed";
    if (typeof d.ageMonths !== "number" || d.ageMonths < 0 || d.ageMonths > 360) return "invalid_age";
    if (!["puppy", "adult", "senior"].includes(d.lifeStage)) return "invalid_life_stage";
    return null;
}

// MARK: - Prompt building

interface Prompt {
    system: string;
    user: string;
    maxTokens: number;
}

const SYSTEM_BASE = `You write for Trot, an iOS app that helps people walk their dogs daily.
You write in the dog's voice — short, warm, plain British English. The dog is the speaker; the user is the human reading.

Rules:
- Use the dog's name where it sounds natural (often, but not in every sentence).
- Plain language. Specific over generic. Numbers when they help.
- Never use the words "pawsome", "barktastic", "fur-ever", or any pun on dog body parts.
- Never shame the user. Never say "don't let me down", "you let me down", or similar. Never imply the user is a bad owner.
- Never use em dashes.
- British English ("realise", not "realize").

Output ONLY the line(s) shown to the user. No prefix, no quotes, no explanation, no extra whitespace.`;

function buildPrompt(kind: Kind, dog: DogInfo, context: Record<string, unknown>): Prompt {
    const dogContext = `Dog: ${dog.name} (${dog.breed}, ${dog.lifeStage}).`;

    switch (kind) {
        case "daily": {
            const hour = num(context.hourLocal, 12);
            const partOfDay = hour < 12 ? "morning" : hour < 17 ? "afternoon" : hour < 22 ? "evening" : "night";
            const minutesToday = num(context.minutesToday, 0);
            const targetMinutes = num(context.targetMinutes, 60);
            const status = minutesToday >= targetMinutes
                ? "target met for today"
                : minutesToday > 0
                    ? `${minutesToday} of ${targetMinutes} minutes done today`
                    : "no walks yet today";

            return {
                system: SYSTEM_BASE,
                user: `${dogContext}
Time: ${partOfDay}.
Status: ${status}.

Write ONE short sentence in ${dog.name}'s voice for the home screen. Could be a question ("Bridge today?"), an observation ("Quiet morning."), or an invitation. Calm, never naggy. No exclamation marks unless the target is met.
Maximum 12 words.`,
                maxTokens: 60,
            };
        }

        case "walk_complete": {
            const minutes = num(context.minutes, 0);
            const isFirstWalk = bool(context.isFirstWalk);
            const landmarksHit = arr(context.landmarksHit);
            const routeName = str(context.routeName);
            const nextLandmark = str(context.nextLandmarkName);

            return {
                system: SYSTEM_BASE,
                user: `${dogContext}
Just finished a ${minutes}-minute walk.
${isFirstWalk ? "This is the FIRST walk with Trot — make it cinematic." : ""}
${landmarksHit.length > 0 ? `Landmarks crossed: ${landmarksHit.join(", ")}.` : ""}
${routeName ? `Route: ${routeName}.` : ""}
${nextLandmark ? `Next landmark coming up: ${nextLandmark}.` : ""}

Write a 1-2 sentence celebration in ${dog.name}'s voice for the post-walk overlay. Speak as ${dog.name} in FIRST PERSON ("I sniffed", "we passed", never "Luna did" or "she walked"). Loud, warm, share-worthy. Exclamation marks ALLOWED here. Reference a specific landmark or moment if one is given. Do not refer to ${dog.name} by name in the line — the user already knows.
Maximum 25 words.`,
                maxTokens: 100,
            };
        }

        case "insight": {
            const pattern = str(context.pattern);
            const detail = str(context.detail);

            return {
                system: SYSTEM_BASE,
                user: `${dogContext}
Pattern observed: ${pattern}.
Detail: ${detail}.

Write ONE sentence in ${dog.name}'s voice that names this pattern. The dog is reflecting on a habit they've noticed. Specific, gently self-aware. No exclamation marks.
Maximum 18 words.`,
                maxTokens: 70,
            };
        }

        case "recap": {
            const minutesThisWeek = num(context.minutesThisWeek, 0);
            const minutesLastWeek = num(context.minutesLastWeek, 0);
            const trend = minutesThisWeek > minutesLastWeek
                ? "up from last week"
                : minutesThisWeek < minutesLastWeek
                    ? "down from last week"
                    : "level with last week";
            const streakDays = num(context.streakDays, 0);

            return {
                system: SYSTEM_BASE,
                user: `${dogContext}
This week: ${minutesThisWeek} minutes walked, ${trend}.
Current streak: ${streakDays} days.

Write a 2-sentence weekly reflection in ${dog.name}'s voice. First sentence names the week (the headline number, the trend). Second sentence is a small specific moment or gentle look forward. Exclamation marks fine if the week was strong.
Maximum 35 words total.`,
                maxTokens: 130,
            };
        }

        case "decay": {
            const daysSinceLastWalk = num(context.daysSinceLastWalk, 3);
            const tone = daysSinceLastWalk <= 4
                ? "gentle, dog-curious"
                : daysSinceLastWalk <= 7
                    ? "quiet, sad-for-self"
                    : "very quiet, accepting";

            return {
                system: SYSTEM_BASE,
                user: `${dogContext}
${daysSinceLastWalk} days since the last walk.
Tone: ${tone}.

Write ONE short sentence in ${dog.name}'s voice. Sad-for-the-dog, never accusatory of the user. Volume goes DOWN, not up. No exclamation marks. No guilt-trip framing. Examples of the right register: "Still here." / "Quiet, ${dog.name}." / "Waiting by the door."
Maximum 10 words.`,
                maxTokens: 50,
            };
        }

        case "onboarding_card": {
            return {
                system: SYSTEM_BASE,
                user: `${dogContext}
This is the very first card the user sees after uploading ${dog.name}'s photo, before any walks have been logged.

Write ONE punchy line in ${dog.name}'s voice that announces them. Warm, excited, share-worthy. Exclamation marks ALLOWED. Use the dog's name. Examples of the right register: "${dog.name}'s here. Let's go!" / "Hi, I'm ${dog.name}. Walk?"
Maximum 10 words.`,
                maxTokens: 50,
            };
        }

        case "moment_unlock": {
            const headlineMomentTitle = str(context.headlineMomentTitle);
            const momentDescription = str(context.momentDescription);
            const allCrossedTitles = arr(context.allCrossedTitles);
            const lifetimeMinutesWithDog = num(context.lifetimeMinutesWithDog, 0);
            const daysSinceFirstWalk = num(context.daysSinceFirstWalk, 0);
            const otherCrossings = allCrossedTitles
                .filter((t) => t !== headlineMomentTitle)
                .slice(0, 4);

            const lifetimeHours = Math.round(lifetimeMinutesWithDog / 60);
            const lifetimeLabel = lifetimeMinutesWithDog < 60
                ? `${lifetimeMinutesWithDog} minutes`
                : lifetimeHours === 1
                    ? "about an hour"
                    : `${lifetimeHours} hours`;

            return {
                system: SYSTEM_BASE,
                user: `${dogContext}
A Moment just unlocked in the user's current season.
Moment: "${headlineMomentTitle}" — ${momentDescription}
${otherCrossings.length > 0 ? `Other moments crossed in the same walk: ${otherCrossings.join(", ")}.` : ""}
Lifetime walking time with this user: ${lifetimeLabel}.
Days since the first walk in the diary: ${daysSinceFirstWalk}.

Write a 1-2 sentence DIARY ENTRY in ${dog.name}'s voice. The dog is reflecting on the moment, speaking ABOUT the user — what they smell like, when they walk, how they walk, something specific. The app is invisible — never mention "Trot", "the app", "tracking", "logged". Don't claim "first ever" of anything (the user may have had this dog for years). Talk about accumulated time and the relationship as it stands. The line should feel like a private observation the dog is making about the human they walk with.

Tone: warm, plain, slightly dry. Specific over generic. The line should make the user feel seen.

Examples of the right register:
- "Your slowest walks. My favourite kind."
- "You always smell like coffee in the mornings. I wait for it."
- "Five hours of rain this winter. You towel my chest first, every time."
- "We've done a lot of walks. You're easier to follow than you think."

Maximum 28 words. No exclamation marks unless the moment is genuinely big.`,
                maxTokens: 130,
            };
        }
    }
}

// MARK: - Anthropic call

async function callAnthropic(apiKey: string, prompt: Prompt): Promise<string> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
        const res = await fetch(ANTHROPIC_URL, {
            method: "POST",
            headers: {
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            body: JSON.stringify({
                model: MODEL,
                max_tokens: prompt.maxTokens,
                system: prompt.system,
                messages: [{ role: "user", content: prompt.user }],
            }),
            signal: controller.signal,
        });
        if (!res.ok) {
            const detail = await res.text().catch(() => "");
            throw new Error(`anthropic_${res.status}: ${detail.slice(0, 200)}`);
        }
        const payload = (await res.json()) as { content?: Array<{ type: string; text?: string }> };
        const block = payload.content?.find((c) => c.type === "text");
        const text = block?.text ?? "";
        if (!text) throw new Error("empty_response");
        return text;
    } finally {
        clearTimeout(timeout);
    }
}

// MARK: - Output sanitisation

/// Strip surrounding quotes/whitespace; reject empty; cap at a defensive max.
function sanitize(raw: string, kind: Kind): string | null {
    let text = raw.trim();
    // Some models wrap output in quotes despite instructions. Strip a single
    // matched pair only.
    if ((text.startsWith('"') && text.endsWith('"')) || (text.startsWith("'") && text.endsWith("'"))) {
        text = text.slice(1, -1).trim();
    }
    // Remove any em dashes the model emitted despite the rule. Replace with a
    // sentence break — cheaper than re-prompting.
    text = text.replace(/—/g, ".").replace(/\s+\./g, ".");

    if (!text) return null;

    // Defensive caps. Recap is the only multi-sentence kind.
    const max = kind === "recap" ? 280 : 140;
    if (text.length > max) text = text.slice(0, max).trim();

    return text;
}

// MARK: - Helpers

function num(v: unknown, fallback: number): number {
    return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}

function str(v: unknown): string {
    return typeof v === "string" ? v : "";
}

function bool(v: unknown): boolean {
    return v === true;
}

function arr(v: unknown): string[] {
    if (!Array.isArray(v)) return [];
    return v.filter((x): x is string => typeof x === "string");
}

function json(payload: SuccessResponse | ErrorResponse, status: number): Response {
    return new Response(JSON.stringify(payload), {
        status,
        headers: { "content-type": "application/json" },
    });
}
