#!/usr/bin/env node
// Lightweight Node.js checks for project metadata and expected CI files.
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../..");
const fail = (message) => { console.error("ERROR:", message); process.exitCode = 1; };
const projectPath = path.join(root, "project.godot");
if (!fs.existsSync(projectPath)) {
  fail("project.godot is missing");
} else {
  const project = fs.readFileSync(projectPath, "utf8");
  const scene = project.match(/^run\/main_scene="([^"]+)"/m)?.[1];
  if (!scene) fail("project.godot does not define run/main_scene");
  else {
    const scenePath = path.join(root, scene.replace(/^res:\/\//, ""));
    if (!fs.existsSync(scenePath)) fail("Main scene is missing: " + scene);
    else {
      const sceneText = fs.readFileSync(scenePath, "utf8");
      for (const [, resource] of sceneText.matchAll(/path="res:\/\/([^"]+)"/g)) {
        if (!fs.existsSync(path.join(root, resource))) fail("Required scene resource is missing: " + resource);
      }
    }
  }
  if (!project.includes('config/name="F.D.F.R.: Florida District Fire & Rescue"')) {
    fail("Project name does not match F.D.F.R.");
  }
}
if (process.exitCode) process.exit(process.exitCode);
console.log("F.D.F.R. Node.js checks passed.");
