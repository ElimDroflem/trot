# Trot — Breed-and-age safe-range table

This file is the data foundation for daily exercise targets. The Vercel LLM proxy references it; the iOS app ships a compiled JSON copy in `ios/Trot/Resources/BreedData.json`.

The LLM **never invents the numbers** — it picks within the ranges this file defines.

## Status

**Schema locked. Data drafting in progress.** v1 ships when ~30–40 most common UK breeds are covered plus the size-based fallback table. Data sources cited per row.

## Sources (authoritative tier, in priority order)

1. **PDSA** (People's Dispensary for Sick Animals) — vet-published guidance, UK-relevant
2. **Kennel Club** (UK) — breed-by-breed exercise notes per breed standard
3. **RSPCA** — welfare-aligned guidance
4. **Breed-club guidance** (e.g. Beagle Association, Labrador Retriever Club) for specific cautions

When sources disagree, the lower (more conservative) figure wins for puppies and seniors. The mid-point of the range is used for healthy adults.

## Schema

Each breed entry has:

```yaml
breed: "Labrador Retriever"        # Canonical name. Match Kennel Club spelling.
aliases: ["Lab", "Labrador"]       # Alternate strings the user might type
size: "large"                      # tiny | small | medium | large | giant
default_intensity: "moderate"      # low | moderate | high

life_stages:
  puppy:                           # Until ~12 months for most breeds; longer for giants
    min_minutes: 15
    max_minutes: 30
    notes: "5 minutes per month of age, twice a day, until growth plates close. No long walks."
  adult:
    min_minutes: 60
    max_minutes: 120
    notes: "Strong swimmers. Mix of walking, fetch, off-lead running."
  senior:                          # 7+ for large breeds, 8+ for medium, 10+ for small
    min_minutes: 30
    max_minutes: 60
    notes: "Watch for arthritis. Two shorter walks better than one long one."

cautions:
  - condition: "hip_dysplasia"     # See conditions.yaml below
    adjustment: "reduce_max"
    note: "Cap at adult.max_minutes minus 30."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Labs gain weight easily. Don't compensate undersupervised treats with extra walks."

sources:
  - "PDSA: https://www.pdsa.org.uk/..."
  - "Kennel Club: https://www.thekennelclub.org.uk/..."
  - "Labrador Retriever Club UK: ..."

last_reviewed: "2026-05-05"
```

## Health-condition adjustments (`conditions.yaml`)

Conditions that modify the per-breed range. Applied after the per-breed value is selected.

```yaml
brachycephalic:                    # Frenchies, Pugs, Bulldogs, Boxers
  reduction: "30%"
  note: "Avoid heat. Two short walks better than one long. Watch for breathing distress."

hip_dysplasia:
  reduction: "20%"
  intensity_cap: "moderate"
  note: "Avoid stairs and jumping. Swimming better than running where available."

arthritis:
  reduction: "30%"
  intensity_cap: "low"
  note: "Multiple short walks. Warm-up matters."

heart_condition:
  reduction: "40%"
  intensity_cap: "low"
  note: "Vet sign-off required. Trot defers to vet guidance."

epilepsy:
  reduction: "0%"
  note: "Avoid extreme heat or exertion. Otherwise normal range."

obesity_risk:
  reduction: "0%"
  note: "Diet-driven, not walk-driven. Adding minutes won't fix obesity if calories aren't managed."

three_legged:
  reduction: "40%"
  intensity_cap: "low"
  note: "Often manage well but plan rest stops."
```

## Fallback table (size + life-stage)

For breeds not in the table — including most mixed breeds where the user picks "primary breed" but the breed isn't covered. Used as a defensible default before LLM personalisation.

| Size | Puppy (min/day) | Adult (min/day) | Senior (min/day) |
|------|-----------------|-----------------|------------------|
| Tiny (<5kg)    | 10–20 | 30–45  | 20–30 |
| Small (5–10kg) | 15–25 | 30–60  | 20–40 |
| Medium (10–25kg)| 20–30 | 45–90  | 30–60 |
| Large (25–45kg)| 20–35 | 60–120 | 30–60 |
| Giant (>45kg)  | 15–25 | 45–90  | 20–45 |

(Giant adults appear lower than large because giant breeds tire faster and are joint-vulnerable. PDSA-aligned.)

## Mixed breeds

For v1, mixed breeds use the user's selected "primary breed" entry. Two-breed weighted averaging is a v1.1 candidate, not v1 scope.

If the primary breed isn't in the table, fall back to the size + life-stage table above.

## Breed data

Coverage of the top 30 UK breeds by rough Kennel Club registration / pet population prevalence. ~80% of UK pet dogs fall under one of these entries (or default to the size-based fallback table for mixes / less common breeds).

**Verification status for this draft:** Network access to source domains (pdsa.org.uk, thekennelclub.org.uk, rspca.org.uk, breed clubs) was unavailable during this research session. Per the workflow rules in this file, all entries below are flagged `last_reviewed: "needs verification"` and `sources: ["TODO: verify pre-launch — sources unreachable in research session"]`. Numeric ranges use the conservative-floor approach: PDSA "5 minutes per month of age, twice daily" for puppies, Kennel Club exercise-level categories for adults (low / moderate / high), and the size-and-life-stage fallback table at the bottom of this file as the senior floor. Brachycephalic, sighthound, and working-breed cautions are baked in. **Pre-launch task:** open each entry, fetch the cited PDSA / KC / RSPCA / breed-club page, confirm or adjust the figures, replace the TODO source line with the real URL, and set `last_reviewed` to the verification date.

### 1. Labrador Retriever

```yaml
breed: "Labrador Retriever"
aliases: ["Lab", "Labrador", "Black Lab", "Yellow Lab", "Chocolate Lab"]
size: "large"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 30
    notes: "PDSA rule: 5 minutes structured exercise per month of age, twice daily. No forced running, no long walks, no stairs until ~12 months. Avoid jumping in and out of cars."
  adult:
    min_minutes: 80
    max_minutes: 120
    notes: "High-energy working breed. Mix of on-lead walking, off-lead running, fetch, and swimming. Strong swimmers — water is excellent low-impact exercise."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 7. Two shorter walks better than one long. Watch for stiffness, weight gain, and slowing pace."

cautions:
  - condition: "hip_dysplasia"
    adjustment: "reduce_max"
    note: "Labradors are predisposed. Cap intensity at moderate if diagnosed; favour swimming over running."
  - condition: "elbow_dysplasia"
    adjustment: "reduce_max"
    note: "Common in the breed. Avoid repetitive jumping and hard surfaces."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Labradors gain weight extremely easily — many carry a known POMC gene variant linked to food drive. Diet matters more than extra walks; do not over-walk to compensate for treats."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 2. French Bulldog

```yaml
breed: "French Bulldog"
aliases: ["Frenchie", "French Bull"]
size: "small"
default_intensity: "low"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily. Brachycephalic — keep sessions short and avoid any heat. Stop at first sign of laboured breathing."
  adult:
    min_minutes: 30
    max_minutes: 60
    notes: "Two short walks per day suits them better than one long one. Cool times of day only. Avoid long off-lead running and any heat above ~20C."
  senior:
    min_minutes: 20
    max_minutes: 40
    notes: "From age 8. Gentle, short walks. Watch for breathing distress and back issues (IVDD risk)."

cautions:
  - condition: "brachycephalic"
    adjustment: "reduce_max"
    note: "BOAS (Brachycephalic Obstructive Airway Syndrome) risk. Never walk in heat. Two short walks beat one long. Stop if breathing becomes laboured, gums turn blue/grey, or excessive panting starts."
  - condition: "ivdd_risk"
    adjustment: "intensity_cap"
    note: "Avoid jumping off furniture, stairs where possible. Use a harness, not a collar."
  - condition: "heat_sensitivity"
    adjustment: "intensity_cap"
    note: "Walk early morning or late evening in summer. Carry water. Heatstroke is a Frenchie killer."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 3. Cocker Spaniel

```yaml
breed: "Cocker Spaniel"
aliases: ["English Cocker", "Cocker", "Working Cocker", "Show Cocker"]
size: "medium"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Sniffing and gentle play matter as much as walking distance."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "Working line needs the upper end and benefits hugely from off-lead time and scent work. Show line is similar but slightly less driven. Mental stimulation (sniff walks, retrieving) reduces total minutes needed."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 8. Still want to work — moderate the duration, keep the variety. Watch ears for infection, eyes for cataracts."

cautions:
  - condition: "ear_infections"
    adjustment: "monitor"
    note: "Long ears and water are a bad mix. Dry ears thoroughly after wet walks or swimming."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Cockers can put weight on quickly if exercise drops."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 4. Cockapoo

```yaml
breed: "Cockapoo"
aliases: ["Cocker Poodle", "Spoodle"]
size: "small"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Cockapoos are intelligent and benefit from training games as much as walking."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "Crossbreed of Cocker Spaniel and Poodle — both working breeds. Daily off-lead time and mental work (puzzles, recall games, sniff walks) keep them balanced."
  senior:
    min_minutes: 30
    max_minutes: 50
    notes: "From age 8-10 depending on size. Slow the pace, keep the variety. Watch for joint stiffness."

cautions:
  - condition: "variable_size"
    adjustment: "monitor"
    note: "Cockapoos vary widely in size depending on parents. Adjust toward the size-based fallback if the dog is markedly smaller or larger than the medium baseline."
  - condition: "ear_infections"
    adjustment: "monitor"
    note: "Inherits floppy, hairy ears from both parents. Keep dry and check regularly."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session — note: Cockapoos are not Kennel Club recognised; guidance derives from Cocker Spaniel and Miniature Poodle parents."

last_reviewed: "needs verification"
```

### 5. English Springer Spaniel

```yaml
breed: "English Springer Spaniel"
aliases: ["Springer", "Springer Spaniel", "ESS"]
size: "medium"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. High drive even as puppies — channel it into short, varied sessions."
  adult:
    min_minutes: 90
    max_minutes: 120
    notes: "One of the most demanding pet breeds for exercise. Working line genuinely needs 2+ hours daily plus mental work (scent, retrieving, training). Show line slightly less but still high. Under-exercised Springers chew, dig, and bolt."
  senior:
    min_minutes: 45
    max_minutes: 75
    notes: "From age 8. Energy stays high longer than most breeds — let them tell you when to slow down. Watch for hip and ear issues."

cautions:
  - condition: "mental_stimulation_need"
    adjustment: "supplement"
    note: "Walking minutes alone do not satisfy this breed. Add sniff games, retrieving, recall work, or proper canine sports."
  - condition: "ear_infections"
    adjustment: "monitor"
    note: "Long, hairy ears. Dry after water; check weekly."
  - condition: "hip_dysplasia"
    adjustment: "monitor"
    note: "Some incidence in working lines. Check parental hip scores if buying a puppy."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 6. Border Collie

```yaml
breed: "Border Collie"
aliases: ["Collie", "BC", "Border"]
size: "medium"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Resist the urge to over-exercise just because they seem tireless — growth plates need protecting."
  adult:
    min_minutes: 90
    max_minutes: 120
    notes: "Bred to work all day. Walking minutes are necessary but not sufficient — mental work (training, agility, scent, problem-solving) matters as much. An under-stimulated Collie is a destructive Collie."
  senior:
    min_minutes: 45
    max_minutes: 75
    notes: "From age 8. Mental work stays valuable even as physical capacity drops. Watch for arthritis, especially in the hips."

cautions:
  - condition: "mental_stimulation_need"
    adjustment: "supplement"
    note: "Highest mental-stimulation need of any common UK breed. Without it, even 3 hours of walking won't be enough. Consider trick training, agility, scent work, or herding-style games."
  - condition: "hip_dysplasia"
    adjustment: "monitor"
    note: "Some incidence. Avoid repetitive jumping in young dogs."
  - condition: "noise_sensitivity"
    adjustment: "behavioural"
    note: "Some Collies are sound-reactive — adjust walk routes to avoid known triggers, not just exercise volume."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 7. German Shepherd Dog

```yaml
breed: "German Shepherd Dog"
aliases: ["GSD", "German Shepherd", "Alsatian"]
size: "large"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 30
    notes: "5 minutes per month of age, twice daily. Large breed — growth plates close later (~18 months). Avoid forced running, repetitive jumping, and stairs."
  adult:
    min_minutes: 90
    max_minutes: 120
    notes: "Working breed needing both physical and mental challenge. Daily off-lead running, training, and scent work. Under-exercised GSDs become anxious or destructive."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 7. Hip and elbow issues common — shorter, gentler walks. Swimming helps where available."

cautions:
  - condition: "hip_dysplasia"
    adjustment: "reduce_max"
    note: "GSDs are one of the highest-risk breeds. Check hip scores before buying. Avoid hard repetitive impact."
  - condition: "elbow_dysplasia"
    adjustment: "reduce_max"
    note: "Also high risk. Same precautions as hips."
  - condition: "degenerative_myelopathy"
    adjustment: "intensity_cap"
    note: "Late-onset spinal condition. If diagnosed, follow vet guidance — usually shorter, easier walks."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 8. Staffordshire Bull Terrier

```yaml
breed: "Staffordshire Bull Terrier"
aliases: ["Staffy", "Staffie", "Stafford", "SBT"]
size: "medium"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Strong, stocky build — keep walks gentle."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "Robust, muscular dogs. Two solid walks daily plus play. Tug, fetch, and scent games suit them. Lead skills matter — Staffies pull."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 8. Tend to slow down gradually. Watch for joint stiffness and skin conditions."

cautions:
  - condition: "heat_sensitivity"
    adjustment: "monitor"
    note: "Slightly brachycephalic. Avoid heat; carry water on warm days."
  - condition: "skin_allergies"
    adjustment: "monitor"
    note: "Common in the breed. Wash paws after grass walks if allergies are suspected."
  - condition: "dog_reactivity"
    adjustment: "behavioural"
    note: "Some Staffies are dog-selective. Lead walks and trusted off-lead spaces; not a breed for chaotic dog parks."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 9. Cavalier King Charles Spaniel

```yaml
breed: "Cavalier King Charles Spaniel"
aliases: ["Cavalier", "CKCS", "King Charles", "Cav"]
size: "small"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily. Small breed — short sessions are plenty."
  adult:
    min_minutes: 45
    max_minutes: 60
    notes: "Happy with two gentle walks plus play. Adapt to family life — will do more if asked but don't need it."
  senior:
    min_minutes: 20
    max_minutes: 40
    notes: "From age 10. Heart and neurological issues commonly limit activity earlier than expected — follow vet guidance."

cautions:
  - condition: "heart_condition"
    adjustment: "intensity_cap"
    note: "Mitral valve disease affects most Cavaliers by age 10. If diagnosed, vet-led exercise plan only — usually shorter, gentler walks."
  - condition: "syringomyelia"
    adjustment: "intensity_cap"
    note: "Neurological condition common in the breed. If diagnosed, avoid neck pressure (use a harness) and follow vet guidance."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Easily overfed. Treats during training count toward daily calories."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 10. Golden Retriever

```yaml
breed: "Golden Retriever"
aliases: ["Golden", "Goldie", "Golden Retriever"]
size: "large"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 30
    notes: "5 minutes per month of age, twice daily. Large breed — protect growth plates until ~12-18 months. No forced running."
  adult:
    min_minutes: 80
    max_minutes: 120
    notes: "Mix of walking, off-lead running, fetch, and swimming. Strong swimmers; water work is ideal. Mental work via retrieving and training matters too."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 7. Two shorter walks beat one long. Watch for arthritis, weight gain, and slowing pace."

cautions:
  - condition: "hip_dysplasia"
    adjustment: "reduce_max"
    note: "Common in the breed. Check hip scores; favour swimming and grass over hard ground."
  - condition: "elbow_dysplasia"
    adjustment: "reduce_max"
    note: "Also common. Avoid repetitive jumping."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Goldens gain weight easily. Diet-led, not walk-led — extra walks won't fix overfeeding."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 11. Beagle

```yaml
breed: "Beagle"
aliases: ["Beagle Hound"]
size: "medium"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Beagles love to follow their nose from very young — start recall and lead training early."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "Scent hound bred to work all day. Sniff walks count for as much as faster walks — let them use their nose. Off-lead only in secure spaces; recall is famously unreliable when a scent hits."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 8. Slow the pace, keep the sniffing. Watch for weight gain — Beagles will overeat given the chance."

cautions:
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Beagles are food-driven and prone to weight gain. Diet matters more than extra walks."
  - condition: "scent_drive"
    adjustment: "behavioural"
    note: "Treat off-lead freedom as a privilege earned through training. A Beagle on a scent will not come back."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 12. Miniature Smooth-Haired Dachshund

```yaml
breed: "Miniature Smooth-Haired Dachshund"
aliases: ["Mini Dachshund", "Miniature Dachshund", "Dachshund", "Sausage Dog", "Doxie", "Dackel"]
size: "small"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily. Long back is vulnerable — no stairs, no jumping off furniture, no rough play."
  adult:
    min_minutes: 45
    max_minutes: 60
    notes: "Two short walks per day plus garden play. Active and bold for their size; happy to do more if offered, but back protection is the bigger constraint."
  senior:
    min_minutes: 20
    max_minutes: 40
    notes: "From age 10. Gentle, level-ground walks. Watch for back pain or any change in gait — IVDD signs need urgent vet attention."

cautions:
  - condition: "ivdd_risk"
    adjustment: "intensity_cap"
    note: "Highest IVDD risk of any breed. No jumping on/off furniture or beds, no stairs (use a ramp or carry). Use a harness, never a collar. Keep weight low."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Excess weight directly worsens IVDD risk. Diet matters more than walk length."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 13. Bulldog (English)

```yaml
breed: "Bulldog"
aliases: ["English Bulldog", "British Bulldog", "Bully"]
size: "medium"
default_intensity: "low"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 15
    notes: "5 minutes per month of age, twice daily. Brachycephalic from birth — keep sessions short, never in heat, stop at first sign of laboured breathing."
  adult:
    min_minutes: 20
    max_minutes: 45
    notes: "Two short, gentle walks daily. Cool times of day only. No running, no extended exertion. Indoor play and short sniff walks are the bulk of their exercise."
  senior:
    min_minutes: 15
    max_minutes: 30
    notes: "From age 8. Very short, gentle walks. Many Bulldogs slow markedly with age."

cautions:
  - condition: "brachycephalic"
    adjustment: "reduce_max"
    note: "Severe BOAS risk. Heat is a killer. Always carry water. If breathing becomes laboured or gums turn blue/grey, stop immediately and cool the dog."
  - condition: "heat_sensitivity"
    adjustment: "intensity_cap"
    note: "Avoid all walks above ~20C. Early morning or late evening only in summer."
  - condition: "joint_issues"
    adjustment: "monitor"
    note: "Hip and elbow dysplasia common. Soft surfaces preferred."
  - condition: "skin_fold_care"
    adjustment: "monitor"
    note: "Not exercise-related but worth flagging — folds need cleaning to prevent infection."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 14. Pug

```yaml
breed: "Pug"
aliases: ["Pug Dog", "Mops"]
size: "small"
default_intensity: "low"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 15
    notes: "5 minutes per month of age, twice daily. Brachycephalic — short sessions only, never in heat."
  adult:
    min_minutes: 20
    max_minutes: 40
    notes: "Two short walks daily, cool times of day. Pugs love food and lounging — gentle, regular activity beats one big walk."
  senior:
    min_minutes: 15
    max_minutes: 30
    notes: "From age 10. Very short, gentle walks. Watch breathing, weight, and eye health."

cautions:
  - condition: "brachycephalic"
    adjustment: "reduce_max"
    note: "BOAS risk is high. Stop at first sign of laboured breathing. Use a harness, never a collar."
  - condition: "heat_sensitivity"
    adjustment: "intensity_cap"
    note: "Heatstroke is a leading killer. Avoid walks above ~20C; cool times of day only in summer."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Pugs gain weight extremely easily. Excess weight worsens breathing — diet is critical."
  - condition: "eye_protection"
    adjustment: "monitor"
    note: "Prominent eyes — avoid undergrowth that could scratch corneas."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 15. Boxer

```yaml
breed: "Boxer"
aliases: ["Deutscher Boxer"]
size: "large"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Mildly brachycephalic and large — protect growth plates and avoid heat."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "High-energy and playful. Two solid walks plus play. Cool times of day — Boxers overheat faster than most large breeds. Mental work helps."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 7. Boxers age faster than many large breeds. Watch for cardiac issues and tumours."

cautions:
  - condition: "brachycephalic"
    adjustment: "reduce_max"
    note: "Mild-to-moderate BOAS risk. Avoid heat. Stop if breathing becomes laboured."
  - condition: "heart_condition"
    adjustment: "intensity_cap"
    note: "Boxer cardiomyopathy is breed-specific. Annual cardiac checks from middle age. Reduce intensity if diagnosed."
  - condition: "heat_sensitivity"
    adjustment: "monitor"
    note: "Cool walks only above ~22C. Carry water."
  - condition: "joint_issues"
    adjustment: "monitor"
    note: "Hip dysplasia and cruciate injuries known. Avoid repetitive impact in young dogs."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 16. Whippet

```yaml
breed: "Whippet"
aliases: ["Whippet Hound"]
size: "medium"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily. Lean, light-boned — gentle is key. Sighthound puppies need controlled exercise to protect growth plates."
  adult:
    min_minutes: 45
    max_minutes: 75
    notes: "Sighthound pattern: short bursts of high-speed sprinting, then long rest. Daily walk plus a safe space for off-lead running covers it. Total minutes are surprisingly modest for the energy on display."
  senior:
    min_minutes: 30
    max_minutes: 50
    notes: "From age 8. Whippets stay sprightly into old age. Shorter sprints, more sniffing."

cautions:
  - condition: "thin_skin"
    adjustment: "monitor"
    note: "Easy to cut on brambles or barbed wire. Check after off-lead runs."
  - condition: "cold_sensitivity"
    adjustment: "monitor"
    note: "Low body fat, thin coat. Use a coat in winter; avoid prolonged cold and wet."
  - condition: "prey_drive"
    adjustment: "behavioural"
    note: "Strong sighthound chase instinct. Off-lead only in fully enclosed spaces unless recall is rock-solid."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 17. West Highland White Terrier

```yaml
breed: "West Highland White Terrier"
aliases: ["Westie", "WHWT"]
size: "small"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily. Sturdy small breed — gentle structured walks plus play."
  adult:
    min_minutes: 45
    max_minutes: 60
    notes: "Two walks daily plus play. Westies enjoy a good explore — sniff walks suit their terrier nose. Confident off-lead but watch prey drive."
  senior:
    min_minutes: 20
    max_minutes: 45
    notes: "From age 10. Slow but keen. Watch for skin conditions and joint stiffness."

cautions:
  - condition: "skin_allergies"
    adjustment: "monitor"
    note: "Westies commonly suffer atopic dermatitis. Wash paws after grass walks; avoid known allergens."
  - condition: "prey_drive"
    adjustment: "behavioural"
    note: "Bred to chase vermin. Strong recall training needed for off-lead."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 18. Border Terrier

```yaml
breed: "Border Terrier"
aliases: ["Border", "BT"]
size: "small"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily. Tough, wiry little dogs — gentle but they have stamina."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "More demanding than most small terriers — bred to keep up with horses. Two solid walks plus off-lead time. Sniff and dig opportunities matter."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 10. Stay active longer than most small breeds. Keep variety."

cautions:
  - condition: "prey_drive"
    adjustment: "behavioural"
    note: "Strong terrier instinct. Recall training essential."
  - condition: "ces_risk"
    adjustment: "monitor"
    note: "Canine Epileptoid Cramping Syndrome (Spike's Disease) is recognised in the breed. If episodes occur, vet referral and dietary adjustment."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 19. Shih Tzu

```yaml
breed: "Shih Tzu"
aliases: ["Shihtzu", "Shi Tzu"]
size: "small"
default_intensity: "low"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 15
    notes: "5 minutes per month of age, twice daily. Mildly brachycephalic — keep sessions short and avoid heat."
  adult:
    min_minutes: 20
    max_minutes: 40
    notes: "Two short walks daily plus indoor play. Companion breed — happy with modest activity."
  senior:
    min_minutes: 15
    max_minutes: 30
    notes: "From age 10. Short, gentle walks. Watch breathing and eyes."

cautions:
  - condition: "brachycephalic"
    adjustment: "reduce_max"
    note: "Mild-to-moderate BOAS risk. Avoid heat. Use a harness, not a collar."
  - condition: "heat_sensitivity"
    adjustment: "intensity_cap"
    note: "Cool times of day only in summer."
  - condition: "eye_protection"
    adjustment: "monitor"
    note: "Prominent eyes — avoid undergrowth. Keep facial hair trimmed away from eyes."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 20. Yorkshire Terrier

```yaml
breed: "Yorkshire Terrier"
aliases: ["Yorkie", "Yorky", "Yorkshire"]
size: "tiny"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 15
    notes: "5 minutes per month of age, twice daily. Tiny and delicate — supervise around bigger dogs and small children."
  adult:
    min_minutes: 30
    max_minutes: 45
    notes: "Two short walks plus indoor play. Yorkies are bold and active for their size — happy to do more if offered, but don't need it."
  senior:
    min_minutes: 15
    max_minutes: 30
    notes: "From age 10. Short, gentle walks. Watch joints and dental health."

cautions:
  - condition: "patella_luxation"
    adjustment: "monitor"
    note: "Common in toy breeds. Avoid jumping from height; keep weight in check."
  - condition: "dental_disease"
    adjustment: "monitor"
    note: "Not exercise-related but worth flagging — Yorkies have notoriously poor dental health without intervention."
  - condition: "cold_sensitivity"
    adjustment: "monitor"
    note: "Tiny body, fine coat. Use a coat in winter."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 21. Hungarian Vizsla

```yaml
breed: "Hungarian Vizsla"
aliases: ["Vizsla", "Magyar Vizsla", "Smooth-Haired Vizsla"]
size: "large"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Lean, athletic build — protect growth plates until ~12-15 months."
  adult:
    min_minutes: 90
    max_minutes: 120
    notes: "One of the highest-energy gun-dog breeds. Daily 2 hours minimum — running, off-lead time, and substantial mental work. Velcro dogs that hate being alone — exercise alone won't fix separation anxiety."
  senior:
    min_minutes: 45
    max_minutes: 75
    notes: "From age 7. Stay active longer than most large breeds — let them tell you when to slow."

cautions:
  - condition: "mental_stimulation_need"
    adjustment: "supplement"
    note: "Walking minutes alone don't satisfy a Vizsla. Add training, gun-dog work, scent, agility."
  - condition: "separation_anxiety"
    adjustment: "behavioural"
    note: "Highly bonded breed. Crate training and gradual alone-time conditioning matter as much as exercise."
  - condition: "cold_sensitivity"
    adjustment: "monitor"
    note: "Single short coat. Use a coat in cold or wet weather."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 22. Rottweiler

```yaml
breed: "Rottweiler"
aliases: ["Rottie", "Rott"]
size: "large"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 30
    notes: "5 minutes per month of age, twice daily. Large breed — growth plates close at 18-24 months. No forced running, no jumping in/out of cars, no stairs as a puppy."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "Strong, powerful working breed. Two solid walks plus mental work — training, scent, controlled play. Pacing matters: under-exercised Rotties get bored and destructive; over-exercised young Rotties damage joints."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 7. Rotties age earlier than smaller breeds. Watch for cancer signs, joint pain, and slowing."

cautions:
  - condition: "hip_dysplasia"
    adjustment: "reduce_max"
    note: "High-risk breed. Hip scores essential. Favour low-impact surfaces."
  - condition: "elbow_dysplasia"
    adjustment: "reduce_max"
    note: "Also common."
  - condition: "obesity_risk"
    adjustment: "monitor_weight"
    note: "Excess weight worsens joint problems badly."
  - condition: "cancer_risk"
    adjustment: "monitor"
    note: "Bone cancer (osteosarcoma) is sadly common. Watch for limping that doesn't resolve."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 23. Lhasa Apso

```yaml
breed: "Lhasa Apso"
aliases: ["Lhasa", "Apso"]
size: "small"
default_intensity: "low"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 15
    notes: "5 minutes per month of age, twice daily."
  adult:
    min_minutes: 30
    max_minutes: 45
    notes: "Two short walks daily plus play. Companion breed — modest needs, tolerant of indoor life."
  senior:
    min_minutes: 15
    max_minutes: 30
    notes: "From age 10. Gentle walks. Watch eyes and joints."

cautions:
  - condition: "eye_conditions"
    adjustment: "monitor"
    note: "Progressive retinal atrophy and other eye issues recognised. Keep facial hair trimmed."
  - condition: "patella_luxation"
    adjustment: "monitor"
    note: "Avoid jumping from height."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 24. Weimaraner

```yaml
breed: "Weimaraner"
aliases: ["Weim", "Grey Ghost"]
size: "large"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 30
    notes: "5 minutes per month of age, twice daily. Large athletic breed — protect growth plates until ~15-18 months."
  adult:
    min_minutes: 90
    max_minutes: 120
    notes: "Among the most demanding pet breeds — bred for all-day hunting. 2 hours daily minimum, with off-lead running and mental work. Under-exercised Weims become destructive and anxious."
  senior:
    min_minutes: 45
    max_minutes: 75
    notes: "From age 7. Stay highly active later than most large breeds."

cautions:
  - condition: "mental_stimulation_need"
    adjustment: "supplement"
    note: "Walking minutes are not enough. Add training, scent work, retrieving, or canine sports."
  - condition: "separation_anxiety"
    adjustment: "behavioural"
    note: "Highly bonded — exercise volume alone doesn't fix loneliness."
  - condition: "bloat_risk"
    adjustment: "monitor"
    note: "Deep-chested breed at risk of GDV. Avoid vigorous exercise immediately before or after meals (1-hour buffer)."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 25. Bichon Frise

```yaml
breed: "Bichon Frise"
aliases: ["Bichon"]
size: "small"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 15
    notes: "5 minutes per month of age, twice daily."
  adult:
    min_minutes: 30
    max_minutes: 45
    notes: "Two short walks daily plus play. Cheerful, sociable breed — happy with moderate activity and benefits from companionship."
  senior:
    min_minutes: 15
    max_minutes: 30
    notes: "From age 10. Gentle walks. Watch eyes and joints."

cautions:
  - condition: "skin_allergies"
    adjustment: "monitor"
    note: "Atopic dermatitis common. Wash paws after walks if reactive."
  - condition: "patella_luxation"
    adjustment: "monitor"
    note: "Avoid jumping from furniture."
  - condition: "separation_anxiety"
    adjustment: "behavioural"
    note: "Highly companion-oriented — manage alone-time gradually."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 26. Lurcher

```yaml
breed: "Lurcher"
aliases: ["Sighthound Cross"]
size: "large"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Lurchers vary widely depending on cross — adjust toward the size of the actual dog."
  adult:
    min_minutes: 45
    max_minutes: 75
    notes: "Sighthound pattern: short sprints, long rest. One walk plus off-lead in safe spaces is usually plenty. Many Lurchers are surprisingly lazy at home."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 8. Often stay sprightly into older age."

cautions:
  - condition: "type_not_breed"
    adjustment: "monitor"
    note: "Lurcher is a working type, not a Kennel Club breed. Crosses vary widely — Greyhound x Collie, Greyhound x Whippet, Saluki x Greyhound etc. Adjust ranges using the dominant parent breed."
  - condition: "thin_skin"
    adjustment: "monitor"
    note: "Sighthound skin tears easily on brambles."
  - condition: "cold_sensitivity"
    adjustment: "monitor"
    note: "Most Lurchers have low body fat. Coat in winter, dry off after wet walks."
  - condition: "prey_drive"
    adjustment: "behavioural"
    note: "Off-lead only in secure spaces unless recall is reliably proofed against running prey."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session — note: Lurcher is not a recognised breed; rely on rescue-organisation and sighthound-rescue guidance pre-launch."

last_reviewed: "needs verification"
```

### 27. Greyhound

```yaml
breed: "Greyhound"
aliases: ["Retired Racing Greyhound", "Pet Greyhound"]
size: "large"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 15
    max_minutes: 25
    notes: "5 minutes per month of age, twice daily. Most pet Greyhounds are rehomed adults from racing — true puppy guidance rarely applies."
  adult:
    min_minutes: 45
    max_minutes: 60
    notes: "Famous '40mph couch potatoes'. Two 20-30 minute walks plus a safe-space sprint usually covers them. Counter-intuitive — they need much less than their build suggests."
  senior:
    min_minutes: 30
    max_minutes: 45
    notes: "From age 8. Gentle on-lead walks. Many ex-racers come with existing wear on joints."

cautions:
  - condition: "thin_skin"
    adjustment: "monitor"
    note: "Greyhound skin tears very easily. Avoid brambles; check after walks."
  - condition: "cold_sensitivity"
    adjustment: "intensity_cap"
    note: "Almost no body fat, single thin coat. Use a coat below ~10C and in wet weather."
  - condition: "prey_drive"
    adjustment: "behavioural"
    note: "Strong chase instinct. Off-lead only in fully enclosed spaces. Many ex-racers should not be off-lead at all."
  - condition: "anaesthesia_sensitivity"
    adjustment: "monitor"
    note: "Not exercise-related but worth flagging to owners — Greyhounds metabolise some anaesthetics differently. Inform any new vet."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 28. Chihuahua (Smooth Coat)

```yaml
breed: "Chihuahua (Smooth Coat)"
aliases: ["Chihuahua", "Chi", "Smooth Coat Chihuahua", "Short-Haired Chihuahua"]
size: "tiny"
default_intensity: "low"

life_stages:
  puppy:
    min_minutes: 5
    max_minutes: 15
    notes: "5 minutes per month of age, twice daily. Tiny and fragile — supervise around larger dogs and children. Avoid jumping from height."
  adult:
    min_minutes: 20
    max_minutes: 40
    notes: "Two short walks plus indoor play. Confident and active for their size, but their needs are genuinely small."
  senior:
    min_minutes: 15
    max_minutes: 30
    notes: "From age 10. Very short, gentle walks. Many Chihuahuas live well into their teens."

cautions:
  - condition: "patella_luxation"
    adjustment: "monitor"
    note: "Very common in toy breeds. Avoid jumping from furniture; ramps help."
  - condition: "cold_sensitivity"
    adjustment: "intensity_cap"
    note: "Tiny body, thin coat. Always use a coat in cold or wet conditions."
  - condition: "dental_disease"
    adjustment: "monitor"
    note: "Tooth crowding leads to early dental disease. Brush regularly."
  - condition: "tracheal_collapse"
    adjustment: "monitor"
    note: "Use a harness, never a collar."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 29. Jack Russell Terrier

```yaml
breed: "Jack Russell Terrier"
aliases: ["JRT", "Jack Russell", "Russell Terrier", "Parson Russell"]
size: "small"
default_intensity: "high"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily. Tough, wiry, busy puppies — channel the energy into short structured sessions."
  adult:
    min_minutes: 60
    max_minutes: 90
    notes: "More demanding than their size suggests — bred to work all day. Two solid walks plus games and off-lead time. Mental stimulation matters; bored JRTs dig and bark."
  senior:
    min_minutes: 30
    max_minutes: 60
    notes: "From age 10. Stay active well into older age. Slow the pace, keep the variety."

cautions:
  - condition: "prey_drive"
    adjustment: "behavioural"
    note: "Bred to hunt vermin underground. Strong recall training and secure off-lead spaces only."
  - condition: "patella_luxation"
    adjustment: "monitor"
    note: "Some incidence — avoid hard repetitive jumping in young dogs."
  - condition: "deafness"
    adjustment: "monitor"
    note: "Higher rate of congenital deafness in mostly-white JRTs. Train hand signals from the start if affected."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session"

last_reviewed: "needs verification"
```

### 30. Cavapoo

```yaml
breed: "Cavapoo"
aliases: ["Cavoodle", "Cavalier Poodle"]
size: "small"
default_intensity: "moderate"

life_stages:
  puppy:
    min_minutes: 10
    max_minutes: 20
    notes: "5 minutes per month of age, twice daily."
  adult:
    min_minutes: 45
    max_minutes: 60
    notes: "Cross of Cavalier King Charles Spaniel and Miniature Poodle. Two walks daily plus play and training. Less demanding than a Cockapoo but more curious than a pure Cavalier."
  senior:
    min_minutes: 20
    max_minutes: 40
    notes: "From age 10. Gentle walks. Watch heart and eye health (Cavalier inheritance)."

cautions:
  - condition: "heart_condition"
    adjustment: "monitor"
    note: "Inherits mitral valve disease risk from Cavalier parent. Annual cardiac checks from middle age."
  - condition: "syringomyelia"
    adjustment: "monitor"
    note: "Possible Cavalier inheritance. Use a harness, not a collar."
  - condition: "ear_infections"
    adjustment: "monitor"
    note: "Floppy hairy ears from both parents. Dry after wet walks."
  - condition: "variable_size"
    adjustment: "monitor"
    note: "Adult size depends on which parent's genes dominate. Adjust ranges if the dog is markedly smaller or larger than the small baseline."

sources:
  - "TODO: verify pre-launch — sources unreachable in research session — note: Cavapoos are not Kennel Club recognised; guidance derives from Cavalier King Charles Spaniel and Miniature Poodle parents."

last_reviewed: "needs verification"
```

## Stretch additions to round out v1 (target 40)

31. Miniature Schnauzer
32. Pomeranian
33. Cavalier Bichon Cross / "Cavachon"
34. Goldendoodle
35. Labradoodle
36. Australian Shepherd
37. Bernese Mountain Dog
38. Newfoundland
39. Great Dane
40. Standard Poodle

## Data drafting workflow

1. For each breed: pull PDSA + Kennel Club guidance. Cross-reference RSPCA when there's a welfare angle (brachy, joint issues, working breeds).
2. Triangulate to a min/max range per life stage. When sources disagree, lower wins.
3. Add cautions specific to the breed (e.g. brachycephalic for Bulldogs/Frenchies/Pugs, joint risk for Labradors and large working breeds).
4. Cite each source with a URL.
5. Set `last_reviewed` to the date you drafted/updated the entry.

When v1 ships, set up a quarterly review reminder — exercise guidance evolves and the sources update.

## Compiled JSON for the iOS bundle

A small build step (or one-shot script) turns this Markdown's structured blocks into `ios/Trot/Resources/BreedData.json`. The iOS app reads the JSON at launch into a typed `BreedData` struct. Don't ship the Markdown — ship the JSON.

The Vercel proxy reads from this same source at build time.

## Open questions

- Should the table support regional variants (e.g. Working Cocker Spaniel needs more exercise than Show Cocker)? **For v1: no — too granular. Use the breed-level entry.**
- Should we expose the rationale (cautions, sources) to the user in the iOS app? **Yes, in the dog profile under "Why this target?" — gives credibility and aligns with the warm-but-credible voice.**
- What if a user enters a breed not in the table AND not picking from a list? **The onboarding flow always presents a searchable list with the size-based fallback as the unlisted option. No free-text breed entry.**
