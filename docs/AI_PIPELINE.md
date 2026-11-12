# AI meal analysis

`MealParser/ClaudeMealParser.swift` turns a photo and a spoken description into meal items matched to real foods. This page explains how it works and the rules that keep its numbers honest.

## The core rule

**Claude never supplies nutrition values.** It:

1. calls `search_foods` to look foods up in the app's databases,
2. chooses results **by `food_id`**,
3. estimates **grams** (and suggests household measures),
4. finishes with `submit_meal`.

The parser keeps a registry of every candidate returned by a search, plus the user's frequent foods. In `submit_meal`, any `food_id` not in that registry becomes "No match found. Tap to search" with zero nutrition, so an invented ID can never inject numbers.

## Request

| Setting | Value | Why |
| --- | --- | --- |
| Model | `claude-sonnet-5-5` | Good vision and tool use at low cost |
| `thinking` | `{"type": "between_tools"}` | No up-front thinking, so it's fast; short notes between tool calls |
| `output_config.effort` | `medium` | Enough reasoning for portions without slowing things down |
| `tool_choice` | `auto` | Sonnet 5.5 rejects forced tool use, so the prompt asks for `submit_meal` and the parser nudges once if it's missing |
| Max rounds | 8 | Stops runaway loops |
| Image | JPEG, about 1024 px, quality 0.7 (`ImagePrep`) | Enough detail, small upload |

Assistant turns are replayed **exactly as received**, which Sonnet 5.5 requires for its thinking blocks.

## What Claude receives

The user message is built from up to four blocks:

1. **The photo** (if any).
2. **The description:** "The user's description of this meal: …"
3. **Size reference** (if plates are set up): the chosen plate's real diameter, plus the list of all the user's plates and bowls so "on my thali" works.
4. **Usual foods:** the user's 25 most frequent `UserFood`s with brand, usual amount (in their usual measure), other names and `food_id`. Claude can use these IDs directly.

The system prompt (`systemPrompt`) covers:

- The description decides **what** is in the meal; the photo decides **how much**, and catches items the user didn't mention.
- Search with short generic terms, then retry with one simpler word if nothing comes back.
- Typical weights to anchor estimates (egg ≈ 50 g, slice of bread ≈ 35 g, and so on).
- **Composite foods:** use one entry if it exists; if only a plainer version exists, add visible extras without double counting.
- **Mixed and home-cooked dishes** from any cuisine (curries, biryani, ramen, pad thai, lasagne, stews…): search for the whole dish first; otherwise estimate a typical home-style recipe, log its ingredients with a shared `dish` name, and make the grams add up to the portion.
- **Cooking fat** (oil or ghee) is always its own item, marked `inferred`, with a question in `note`.
- Household **measures** for each item and the `display_unit` that best describes the amount; spoken household amounts are converted with typical weights.
- `origin` (`voice`, `photo`, `inferred`) and `confidence` (0–1) for every item.

## Tools

**`search_foods(query)`** → `FoodSearchEngine.search`

Returns compact JSON: `food_id`, `name`, `source`, `detail`, `per_100g` (kcal, protein, fat, carbs) and `typical_serving_g` when known. Search order:

1. Saved foods (matching names, aliases and brands; frequent first)
2. AFCD (bundled, offline)
3. Open Food Facts, only for brand-like queries or when there are fewer than 2 results
4. USDA, only when there are still fewer than 2 results
5. If nothing matches every word: each word on its own

**`submit_meal(items)`**, where each item has:

| Field | Meaning |
| --- | --- |
| `name` | Display name, e.g. "Fried egg" |
| `food_id` | From search results, or `""` |
| `grams` | Estimated amount eaten |
| `origin` | `voice` / `photo` / `inferred` |
| `confidence` | 0–1; under 0.6 shows a **Check** tag |
| `note` | Optional question or caveat |
| `measures` | 2–3 `{unit, grams}` household measures |
| `display_unit` | The measure to show, e.g. `cup` |
| `dish` | Recipe group name for estimated dishes |

## After the response

1. `ParsedMealItem`s are converted to `DraftItem`s (adding the label serving and remembered measures).
2. `PortionLearning.apply` adjusts **photo-estimated** amounts using learned corrections:
   - per food after 2 corrected meals, or overall after 5,
   - per dish for recipes,
   - never for spoken amounts or inferred extras,
   - always with a visible note ("Adjusted +30% to match your usual portions").
3. The review screen opens. Saving records the corrections and updates remembered foods.

## Household measures for searched foods

The food databases only give values per 100 g. When you pick a food from search in the item editor, `MeasureLookup` finds measures such as cup, slice or piece, plus that food's own tbsp and tsp weights (a tablespoon of flour is about 8 g, oil about 14 g, honey about 21 g):

1. For USDA foods, it reads the measured portions from the USDA food details endpoint (`foodPortions`). This is real data.
2. It then asks `claude-haiku-5-5` for 2–3 typical measures and spoon weights to fill any gaps. This is a single small JSON reply with no tools.

Results are saved in `food-measures.json` (`MeasureCache`), so each food is looked up once. Only weights come from this step; nutrition values still come from the database. Photo and voice meals get their measures from the main prompt, which also asks for spoon weights on spoonable foods.

## Cost

A typical meal is one image plus 2–4 short rounds, roughly one or two US cents at Sonnet 5.5 prices ($2 / $10 per million input / output tokens).

## Changing the model or prompt

- `model`, `maxRounds`, `thinking` and `effort` are set in `ClaudeMealParser` and `send(_:)`.
- Prompt and tool definitions are the `systemPrompt` and `tools` properties at the bottom of the file.
- Check the current model's docs before switching. Sonnet 5.5, for example, rejects `temperature` and forced `tool_choice`.
