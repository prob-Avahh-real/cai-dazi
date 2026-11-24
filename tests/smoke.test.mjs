import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

test('XcodeGen project.yml defines iOS 18 Swift 6 target and CloudKit entitlements', () => {
  const yml = fs.readFileSync(path.join(ROOT, 'project.yml'), 'utf8');
  assert.match(yml, /name:\s*菜搭子/);
  assert.match(yml, /PRODUCT_BUNDLE_IDENTIFIER:\s*com\.caidaizi\.app/);
  assert.match(yml, /SWIFT_VERSION:\s*"6\.0"/);
  assert.match(yml, /iCloud\.com\.caidaizi\.app/);

  for (const rel of [
    'App/菜搭子App.swift',
    'Models/Models.swift',
    'Models/SeedData.swift',
    'Services/KnowledgeBaseService.swift',
    'Services/RecognitionService.swift',
    'Resources/Info.plist',
    'Resources/菜搭子.entitlements',
  ]) {
    assert.ok(fs.existsSync(path.join(ROOT, rel)), `expected ${rel} to exist`);
  }
});

test('SwiftData models define DynamicFieldable entities and formatting rules', () => {
  const models = fs.readFileSync(path.join(ROOT, 'Models/Models.swift'), 'utf8');
  for (const modelName of ['Ingredient', 'Recipe', 'RecipeIngredient', 'Category', 'Tag', 'ScanRecord']) {
    assert.match(models, new RegExp(`final class ${modelName}\\b`), `missing @Model class ${modelName}`);
  }
  assert.match(models, /protocol DynamicFieldable/);
  assert.match(models, /struct AnyCodable:\s*Codable,\s*Hashable/);
  assert.match(models, /var formattedCookingTime:\s*String/);
  assert.match(models, /var difficultyLabel:\s*String/);
});

test('SeedData populates valid built-in ingredients and cross-referenced recipes', () => {
  const seed = fs.readFileSync(path.join(ROOT, 'Models/SeedData.swift'), 'utf8');
  const ingredientMatches = [...seed.matchAll(/\("([^"]+)",\s*"([^"]+)",\s*\[([^\]]*)\]/g)];
  assert.ok(ingredientMatches.length >= 20, `expected >=20 built-in ingredients, got ${ingredientMatches.length}`);

  const ingredientNames = new Set(ingredientMatches.map((m) => m[1]));
  for (const expected of ['番茄', '土豆', '鸡蛋', '牛肉', '西兰花', '豆腐']) {
    assert.ok(ingredientNames.has(expected), `expected built-in ingredient ${expected}`);
  }

  for (const recipeName of ['番茄炒蛋', '土豆烧牛肉', '青椒肉丝', '葱油拌面', '西兰花炒虾仁', '麻婆豆腐']) {
    assert.ok(seed.includes(`("${recipeName}"`), `expected built-in recipe ${recipeName}`);
  }

  // Every recipe ingredient reference in SeedData must resolve to a defined ingredient
  const recipeRefs = [...seed.matchAll(/\("([^"]+)",\s*"[^"]+",\s*(?:true|false)\)/g)].map((m) => m[1]);
  assert.ok(recipeRefs.length >= 25, 'expected recipe ingredient links');
  for (const ref of recipeRefs) {
    assert.ok(ingredientNames.has(ref), `recipe references undefined seed ingredient: ${ref}`);
  }
});
