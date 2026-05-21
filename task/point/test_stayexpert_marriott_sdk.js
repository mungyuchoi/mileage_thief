#!/usr/bin/env node

const childProcess = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const PACKAGE_SPEC = "marriott@0.0.1";

function run(command, args, options = {}) {
  return childProcess.execFileSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options,
  });
}

function statSize(filePath) {
  try {
    return fs.statSync(filePath).size;
  } catch {
    return null;
  }
}

function main() {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "stayexpert-marriott-"));

  console.log(`[inspect] package=${PACKAGE_SPEC}`);
  console.log(`[inspect] tmp=${tmpDir}`);

  const packOutput = run("npm", ["pack", PACKAGE_SPEC, "--pack-destination", tmpDir]);
  const tarballName = packOutput
    .trim()
    .split(/\r?\n/)
    .find((line) => line.endsWith(".tgz"));

  if (!tarballName) {
    throw new Error(`npm pack did not return a tarball name: ${packOutput}`);
  }

  const tarballPath = path.join(tmpDir, tarballName);
  run("tar", ["-xzf", tarballPath, "-C", tmpDir]);

  const packageDir = path.join(tmpDir, "package");
  const packageJsonPath = path.join(packageDir, "package.json");
  const libPath = path.join(packageDir, "lib", "marriott.js");
  const indexPath = path.join(packageDir, "index.js");

  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  const libSource = fs.readFileSync(libPath, "utf8");
  const indexSource = fs.readFileSync(indexPath, "utf8");

  let loaded;
  let loadError = null;
  try {
    loaded = require(packageDir);
  } catch (error) {
    loadError = error;
  }

  const exportType = typeof loaded;
  const exportKeys =
    loaded && (exportType === "object" || exportType === "function")
      ? Object.keys(loaded)
      : [];
  const hasSearch = Boolean(loaded && typeof loaded.search === "function");
  const hasImplementation = libSource.trim().length > 0;
  const usable = hasImplementation && hasSearch;

  console.log(`name=${packageJson.name}`);
  console.log(`version=${packageJson.version}`);
  console.log(`repository=${packageJson.repository && packageJson.repository.url}`);
  console.log(`index_bytes=${statSize(indexPath)}`);
  console.log(`lib_marriott_js_bytes=${statSize(libPath)}`);
  console.log(`index_source=${JSON.stringify(indexSource.trim())}`);
  console.log(`exports_type=${loadError ? "load_error" : exportType}`);
  console.log(`exports_keys=${exportKeys.length ? exportKeys.join(",") : "(none)"}`);
  console.log(`has_search=${hasSearch}`);
  console.log(`usable=${usable}`);

  if (loadError) {
    console.log(`[verdict] Not usable: package failed to load: ${loadError.message}`);
    return;
  }

  if (!hasImplementation) {
    console.log("[verdict] Not usable: lib/marriott.js is empty in the npm package.");
    return;
  }

  if (!hasSearch) {
    console.log("[verdict] Not usable for the README example: exported search() is missing.");
    return;
  }

  console.log("[verdict] Usable: package exports search().");
}

try {
  main();
} catch (error) {
  console.error(`[error] ${error.stack || error.message}`);
  process.exitCode = 1;
}
