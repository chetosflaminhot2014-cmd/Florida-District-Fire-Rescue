#!/usr/bin/env node
// Static integrity checks for the F.D.F.R. Godot project.
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../..");
const errors = [];
const fail = (message) => errors.push(message);

function walk(dir, ext, found = []) {
  if (!fs.existsSync(dir)) return found;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === ".godot") continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, ext, found);
    else if (entry.isFile() && full.endsWith(ext)) found.push(full);
  }
  return found;
}
function resolveResource(reference) {
  if (reference.startsWith("res://")) {
    const p = path.join(root, reference.slice("res://".length));
    return fs.existsSync(p) ? p : null;
  }
  if (reference.startsWith("uid://")) {
    for (const candidate of walk(root, ".tscn")) {
      const header = fs.readFileSync(candidate, "utf8").slice(0, 1000);
      if (header.includes('uid="' + reference + '"')) return candidate;
    }
  }
  return null;
}
const projectPath = path.join(root, "project.godot");
if (!fs.existsSync(projectPath)) {
  fail("project.godot is missing");
} else {
  const project = fs.readFileSync(projectPath, "utf8");
  const scene = project.match(/^run\/main_scene="([^"]+)"/m)?.[1];
  if (!scene) fail("project.godot does not define run/main_scene");
  else {
    const scenePath = resolveResource(scene);
    if (!scenePath) fail("Cannot resolve main scene reference: " + scene);
    else {
      const sceneText = fs.readFileSync(scenePath, "utf8");
      for (const [, resource] of sceneText.matchAll(/path="(res:\/\/[^"]+)"/g)) {
        if (!resolveResource(resource)) fail("Required scene resource is missing: " + resource);
      }
    }
  }
  if (!project.includes('config/name="F.D.F.R.: Florida District Fire & Rescue"')) {
    fail("Project name does not match F.D.F.R.");
  }
}
if (errors.length) {
  for (const error of errors) console.error("ERROR:", error);
  process.exit(1);
}
console.log("F.D.F.R. Node.js checks passed.");
