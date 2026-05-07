// Vercel Edge Function — exercise-plan
//
// LLM proxy: takes a dog profile, returns a daily exercise target (minutes/day)
// plus a short rationale, picked WITHIN the ranges defined by the breed table.
// The LLM never invents numbers — it picks within ranges this function feeds it.
//
// On any failure (timeout, upstream error, malformed output), the iOS app falls
// back to ExerciseTargetService's safe-range value silently — so this function
// is allowed to return 5xx without breaking onboarding.
//
// Source-of-truth note: ./breed-data.json is a copy of
// ios/Trot/Trot/Resources/BreedData.json. Both derive from docs/breed-table.md.
// TODO(corey, pre-launch): wire a build-time check that fails if the two diverge.

import breedData from "./breed-data.json";

export const config = { runtime: "edge" };

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-haiku-4-5-20251001";
const TIMEOUT_MS = 8_000;

type Size = "tiny" | "small" | "medium" | "large" | "giant";
type LifeStage = "puppy" | "adult" | "senior";

interface RequestBody {
    installToken: string;
    dog: {
        breed: string;
        weightKg: number;
        ageMonths: number;
        sex: "male" | "female";
        isNeutered: boolean;
        activityLevel: "low" | "moderate" | "high";
        health: {
            arthritis: boolean;
            hipDysplasia: boolean;
            brachycephalic: boolean;
            notes?: string;
        };
    };
}

interface BreedEntry {
    breed: string;
    aliases: string[];
    size: Size;
    defaultIntensity: string;
    lifeStages: Record<LifeStage, { min: number; max: number }>;
}

interface SuccessResponse {
    targetMinutes: number;
    targetRange: { min: number; max: number };
    rationale: string;
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

    const range = pickRange(body.dog);
    const prompt = buildPrompt(body.dog, range);

    let llmText: string;
    try {
        llmText = await callAnthropic(apiKey, prompt);
    } catch (err) {
        const reason = err instanceof Error && err.name === "AbortError" ? "timeout" : "upstream_error";
        console.error("anthropic_call_failed", { reason });
        return json({ error: reason }, 502);
    }

    const parsed = parseLLMOutput(llmText, range);
    if (!parsed) {
        console.error("llm_output_unparseable", { sample: llmText.slice(0, 200) });
        return json({ error: "llm_output_invalid" }, 502);
    }

    const response: SuccessResponse = {
        targetMinutes: parsed.targetMinutes,
        targetRange: range,
        rationale: parsed.rationale,
        modelVersion: MODEL,
        source: "llm",
    };
    return json(response, 200);
}

// MARK: - Validation

function validate(body: RequestBody): string | null {
    if (!body || typeof body !== "object") return "invalid_body";
    if (typeof body.installToken !== "string" || body.installToken.length < 8) return "invalid_install_token";
    const d = body.dog;
    if (!d || typeof d !== "object") return "invalid_dog";
    if (typeof d.breed !== "string") return "invalid_breed";
    if (typeof d.weightKg !== "number" || d.weightKg <= 0 || d.weightKg > 150) return "invalid_weight";
    if (typeof d.ageMonths !== "number" || d.ageMonths < 0 || d.ageMonths > 360) return "invalid_age";
    if (d.sex !== "male" && d.sex !== "female") return "invalid_sex";
    if (typeof d.isNeutered !== "boolean") return "invalid_neutered";
    if (!["low", "moderate", "high"].includes(d.activityLevel)) return "invalid_activity_level";
    if (!d.health || typeof d.health !== "object") return "invalid_health";
    return null;
}

// MARK: - Range selection (mirrors ExerciseTargetService.swift)

function pickRange(dog: RequestBody["dog"]): { min: number; max: number } {
    const entry = matchBreed(dog.breed);
    const size = entry?.size ?? sizeForWeight(dog.weightKg);
    const stages = entry?.lifeStages ?? breedData.fallback[size];
    const stage = lifeStage(dog.ageMonths, size);
    const range = stages[stage];

    const reductionPercent = largestReduction(dog.health);
    const factor = 1 - reductionPercent / 100;
    return {
        min: roundToFive(range.min * factor),
        max: roundToFive(range.max * factor),
    };
}

function matchBreed(name: string): BreedEntry | undefined {
    const target = normalize(name);
    if (!target) return undefined;
    return (breedData.breeds as BreedEntry[]).find((entry) => {
        if (normalize(entry.breed) === target) return true;
        return entry.aliases.some((alias) => normalize(alias) === target);
    });
}

function normalize(s: string): string {
    return s.toLowerCase().replace(/[^a-z0-9]/g, "");
}

function sizeForWeight(kg: number): Size {
    if (kg < 5) return "tiny";
    if (kg < 10) return "small";
    if (kg < 25) return "medium";
    if (kg < 45) return "large";
    return "giant";
}

function lifeStage(ageMonths: number, size: Size): LifeStage {
    if (ageMonths < 12) return "puppy";
    const years = Math.floor(ageMonths / 12);
    const seniorAt = breedData.seniorAgeYearsBySize[size] ?? 8;
    return years >= seniorAt ? "senior" : "adult";
}

function largestReduction(health: RequestBody["dog"]["health"]): number {
    const c = breedData.conditions;
    const values: number[] = [];
    if (health.arthritis) values.push(c.arthritis.reductionPercent);
    if (health.hipDysplasia) values.push(c.hipDysplasia.reductionPercent);
    if (health.brachycephalic) values.push(c.brachycephalic.reductionPercent);
    return values.length > 0 ? Math.max(...values) : 0;
}

function roundToFive(value: number): number {
    return Math.max(5, Math.round(value / 5) * 5);
}

// MARK: - Anthropic call

function buildPrompt(dog: RequestBody["dog"], range: { min: number; max: number }): string {
    const healthFlags = [
        dog.health.arthritis && "arthritis",
        dog.health.hipDysplasia && "hip dysplasia",
        dog.health.brachycephalic && "brachycephalic (flat-faced)",
    ].filter(Boolean).join(", ") || "none";

    const ageYears = Math.floor(dog.ageMonths / 12);
    const ageMonthsRemainder = dog.ageMonths % 12;
    const ageString = ageYears > 0
        ? `${ageYears}y ${ageMonthsRemainder}m`
        : `${ageMonthsRemainder}m`;

    return `Pick a daily walking-exercise target for this dog.

Dog:
- Breed: ${dog.breed}
- Age: ${ageString}
- Weight: ${dog.weightKg}kg
- Sex: ${dog.sex}, neutered: ${dog.isNeutered}
- Owner-rated activity level: ${dog.activityLevel}
- Health conditions: ${healthFlags}
- Notes: ${dog.health.notes || "none"}

Safe range for this dog (already adjusted for breed, size, life stage, and health): ${range.min}–${range.max} minutes per day.

Pick a single integer number of minutes WITHIN that range (inclusive on both ends). Do not go below the minimum or above the maximum under any circumstance. Round to the nearest 5.

Then write a one-sentence rationale that mentions the breed and the key driver of the choice (life stage, weight, health, or activity level). British English. Plain language. No exclamation marks. Do not use the words "pawsome", "barktastic", "fur-ever", or any pun on dog body parts.

Respond ONLY with JSON, no prose around it:
{"targetMinutes": <integer>, "rationale": "<one sentence>"}`;
}

async function callAnthropic(apiKey: string, prompt: string): Promise<string> {
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
                max_tokens: 256,
                messages: [{ role: "user", content: prompt }],
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

// MARK: - LLM output parsing

function parseLLMOutput(
    text: string,
    range: { min: number; max: number },
): { targetMinutes: number; rationale: string } | null {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;
    let obj: { targetMinutes?: unknown; rationale?: unknown };
    try {
        obj = JSON.parse(jsonMatch[0]);
    } catch {
        return null;
    }
    if (typeof obj.targetMinutes !== "number" || !Number.isFinite(obj.targetMinutes)) return null;
    if (typeof obj.rationale !== "string" || obj.rationale.trim().length === 0) return null;

    // Defensive clamp: LLM picked outside the safe range, snap back. No crash for the user.
    const clamped = Math.max(range.min, Math.min(range.max, Math.round(obj.targetMinutes)));
    return {
        targetMinutes: clamped,
        rationale: obj.rationale.trim(),
    };
}

// MARK: - Helpers

function json(payload: SuccessResponse | ErrorResponse, status: number): Response {
    return new Response(JSON.stringify(payload), {
        status,
        headers: { "content-type": "application/json" },
    });
}
